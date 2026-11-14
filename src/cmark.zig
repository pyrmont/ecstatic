//! cmark-gfm for Ecstatic: parsing Markdown, editing the tree of nodes and
//! rendering it as HTML.
//!
//! `cmark/parse` returns the document node. Every node belongs to a document,
//! a payload that owns the tree and frees it when no node of it is reachable.
//! A node handle refers to its document, so the document lives as long as
//! any handle does.
//!
//! A node that is unlinked from the tree, or made with `cmark/new`, has no
//! parent and is not freed with the tree. The document keeps a list of these
//! nodes and frees, when it is collected, each one that still has no parent.
//! A node handle therefore never points at freed memory, whatever is done to
//! the tree.

const std = @import("std");
const wattle = @import("wattle");

const Node = opaque {};

extern fn cmark_parse_document(buffer: [*]const u8, len: usize, options: c_int) ?*Node;
extern fn cmark_render_html(root: *Node, options: c_int, extensions: ?*anyopaque) ?[*:0]u8;
extern fn cmark_node_new(node_type: c_int) ?*Node;
extern fn cmark_node_free(node: *Node) void;
extern fn cmark_node_get_type(node: *Node) c_int;
extern fn cmark_node_parent(node: *Node) ?*Node;
extern fn cmark_node_first_child(node: *Node) ?*Node;
extern fn cmark_node_next(node: *Node) ?*Node;
extern fn cmark_node_get_literal(node: *Node) ?[*:0]const u8;
extern fn cmark_node_set_literal(node: *Node, content: [*:0]const u8) c_int;
extern fn cmark_node_get_fence_info(node: *Node) ?[*:0]const u8;
extern fn cmark_node_set_fence_info(node: *Node, info: [*:0]const u8) c_int;
extern fn cmark_node_get_url(node: *Node) ?[*:0]const u8;
extern fn cmark_node_set_url(node: *Node, url: [*:0]const u8) c_int;
extern fn cmark_node_get_title(node: *Node) ?[*:0]const u8;
extern fn cmark_node_set_title(node: *Node, title: [*:0]const u8) c_int;
extern fn cmark_node_get_heading_level(node: *Node) c_int;
extern fn cmark_node_unlink(node: *Node) void;
extern fn cmark_node_insert_before(node: *Node, sibling: *Node) c_int;
extern fn cmark_node_insert_after(node: *Node, sibling: *Node) c_int;
extern fn cmark_node_append_child(node: *Node, child: *Node) c_int;
extern fn cmark_node_prepend_child(node: *Node, child: *Node) c_int;
extern fn free(ptr: ?*anyopaque) void;

const block: c_int = 0x8000;
const @"inline": c_int = 0xC000;
const document_type: c_int = block | 0x0001;

/// The names of the node types, as keywords, with their values in
/// `cmark_node_type`.
const types = [_]struct { name: []const u8, value: c_int }{
    .{ .name = "document", .value = document_type },
    .{ .name = "block-quote", .value = block | 0x0002 },
    .{ .name = "list", .value = block | 0x0003 },
    .{ .name = "item", .value = block | 0x0004 },
    .{ .name = "code-block", .value = block | 0x0005 },
    .{ .name = "html-block", .value = block | 0x0006 },
    .{ .name = "custom-block", .value = block | 0x0007 },
    .{ .name = "paragraph", .value = block | 0x0008 },
    .{ .name = "heading", .value = block | 0x0009 },
    .{ .name = "thematic-break", .value = block | 0x000a },
    .{ .name = "footnote-definition", .value = block | 0x000b },
    .{ .name = "text", .value = @"inline" | 0x0001 },
    .{ .name = "softbreak", .value = @"inline" | 0x0002 },
    .{ .name = "linebreak", .value = @"inline" | 0x0003 },
    .{ .name = "code", .value = @"inline" | 0x0004 },
    .{ .name = "html-inline", .value = @"inline" | 0x0005 },
    .{ .name = "custom-inline", .value = @"inline" | 0x0006 },
    .{ .name = "emph", .value = @"inline" | 0x0007 },
    .{ .name = "strong", .value = @"inline" | 0x0008 },
    .{ .name = "link", .value = @"inline" | 0x0009 },
    .{ .name = "image", .value = @"inline" | 0x000a },
    .{ .name = "footnote-reference", .value = @"inline" | 0x000b },
};

// ==========================================================================
// Documents
// ==========================================================================

/// The payload that owns a tree. `orphans` holds the `n` nodes without a
/// parent that the tree does not own, in an allocation of `cap`.
const Doc = struct {
    root: *Node,
    orphans: [*]*Node,
    n: usize,
    cap: usize,
};

fn docGc(self: *Doc, _: usize) void {
    // Every node is read before any is freed, because freeing an orphan frees
    // the nodes inserted under it, which may be orphans in the list too.
    var keep: usize = 0;
    for (0..self.n) |i| {
        const o = self.orphans[i];
        if (o != self.root and cmark_node_parent(o) == null) {
            self.orphans[keep] = o;
            keep += 1;
        }
    }
    for (0..keep) |i| cmark_node_free(self.orphans[i]);
    if (self.cap > 0) wattle.free(self.orphans[0..self.cap]);
    cmark_node_free(self.root);
}

const doc_type = wattle.define(Doc, .{
    .name = "cmark/document",
    .gc = docGc,
});

/// Records `node` as an orphan of `doc`, unless it is already recorded.
fn adopt(doc: *Doc, node: *Node) wattle.Error!void {
    for (0..doc.n) |i| if (doc.orphans[i] == node) return;
    if (doc.n == doc.cap) {
        const cap = if (doc.cap == 0) 8 else doc.cap * 2;
        const grown = wattle.alloc(*Node, cap) orelse return wattle.panic("out of memory");
        for (0..doc.n) |i| grown[i] = doc.orphans[i];
        if (doc.cap > 0) wattle.free(doc.orphans[0..doc.cap]);
        doc.orphans = grown.ptr;
        doc.cap = cap;
    }
    doc.orphans[doc.n] = node;
    doc.n += 1;
}

// ==========================================================================
// Node handles
// ==========================================================================

/// A handle to a node of the document `doc`, whose wrapped value is `owner`.
const Handle = struct {
    node: *Node,
    doc: *Doc,
    owner: wattle.Value,
};

fn handleMark(self: *Handle, _: usize) void {
    wattle.mark(self.owner);
}

const handle_type = wattle.define(Handle, .{
    .name = "cmark/node",
    .gcmark = handleMark,
});

fn wrap(owner: wattle.Value, doc: *Doc, node: ?*Node) wattle.Value {
    const n = node orelse return wattle.nil();
    const h = wattle.new(Handle, &handle_type, null);
    h.* = .{ .node = n, .doc = doc, .owner = owner };
    return wattle.abstract(h);
}

fn getHandle(argv: []wattle.Value, n: i32) wattle.Error!*Handle {
    return wattle.getAbstract(Handle, argv, n, &handle_type);
}

fn typeName(node: *Node) wattle.Value {
    const t = cmark_node_get_type(node);
    for (types) |entry| if (entry.value == t) return wattle.keyword(entry.name);
    return wattle.nil();
}

fn typeValue(v: wattle.Value) wattle.Error!c_int {
    const name = wattle.toKeyword(v) orelse return wattle.panic("expected a keyword for the node type");
    for (types) |entry| if (std.mem.eql(u8, entry.name, name)) return entry.value;
    return wattle.panicFormat("unknown node type :{s}", .{name});
}

fn optString(s: ?[*:0]const u8) wattle.Value {
    return if (s) |p| wattle.string(std.mem.span(p)) else wattle.nil();
}

/// Calls `set` on the node with a NUL-terminated copy of `bytes`, and raises
/// if cmark refuses the value for the node's type.
fn setString(node: *Node, bytes: []const u8, set: *const fn (*Node, [*:0]const u8) callconv(.c) c_int, what: []const u8) wattle.Error!void {
    const copy = wattle.alloc(u8, bytes.len + 1) orelse return wattle.panic("out of memory");
    defer wattle.free(copy);
    @memcpy(copy[0..bytes.len], bytes);
    copy[bytes.len] = 0;
    if (set(node, @ptrCast(copy.ptr)) == 0)
        return wattle.panicFormat("cannot set the {s} of a :{s} node", .{ what, wattle.toKeyword(typeName(node)) orelse "unknown" });
}

// ==========================================================================
// Functions
// ==========================================================================

/// Implements `(cmark/parse text options)`.
fn parse(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    const text = try wattle.getBytes(argv, 0);
    const options = try wattle.getInteger(argv, 1);
    const root = cmark_parse_document(text.ptr, text.len, options) orelse return wattle.panic("out of memory");
    const doc = wattle.new(Doc, &doc_type, null);
    doc.* = .{ .root = root, .orphans = undefined, .n = 0, .cap = 0 };
    return wrap(wattle.abstract(doc), doc, root);
}

/// Implements `(cmark/render-html node options)`.
fn renderHtml(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    const h = try getHandle(argv, 0);
    const options = try wattle.getInteger(argv, 1);
    const html = cmark_render_html(h.node, options, null) orelse return wattle.panic("out of memory");
    defer free(html);
    return wattle.string(std.mem.span(html));
}

/// Implements `(cmark/new node type)`.
fn new(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    const h = try getHandle(argv, 0);
    const t = try typeValue(argv[1]);
    if (t == document_type) return wattle.panic("cannot make a :document node");
    const node = cmark_node_new(t) orelse return wattle.panic("out of memory");
    try adopt(h.doc, node);
    return wrap(h.owner, h.doc, node);
}

/// Implements `(cmark/nodes node)`: the node and its descendants, in the
/// order of the document.
fn nodes(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    const h = try getHandle(argv, 0);
    const out = wattle.array(&.{});
    var cur: ?*Node = h.node;
    while (cur) |n| {
        try wattle.arrayPush(out, wrap(h.owner, h.doc, n));
        if (cmark_node_first_child(n)) |child| {
            cur = child;
            continue;
        }
        // Climb until a node has a next sibling, stopping at the start.
        var up: ?*Node = n;
        cur = null;
        while (up) |u| {
            if (u == h.node) break;
            if (cmark_node_next(u)) |sibling| {
                cur = sibling;
                break;
            }
            up = cmark_node_parent(u);
        }
    }
    return out;
}

/// Implements `(cmark/children node)`.
fn children(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    const h = try getHandle(argv, 0);
    const out = wattle.array(&.{});
    var cur = cmark_node_first_child(h.node);
    while (cur) |n| : (cur = cmark_node_next(n)) try wattle.arrayPush(out, wrap(h.owner, h.doc, n));
    return out;
}

/// Implements `(cmark/parent node)`.
fn parent(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    const h = try getHandle(argv, 0);
    return wrap(h.owner, h.doc, cmark_node_parent(h.node));
}

/// Implements `(cmark/type node)`.
fn typeOf(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    return typeName((try getHandle(argv, 0)).node);
}

/// Implements `(cmark/same? a b)`.
fn same(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    return wattle.boolean((try getHandle(argv, 0)).node == (try getHandle(argv, 1)).node);
}

fn literal(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    return optString(cmark_node_get_literal((try getHandle(argv, 0)).node));
}

fn setLiteral(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    const h = try getHandle(argv, 0);
    try setString(h.node, try wattle.getBytes(argv, 1), &cmark_node_set_literal, "literal");
    return argv[0];
}

fn fenceInfo(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    const h = try getHandle(argv, 0);
    if (cmark_node_get_type(h.node) != block | 0x0005) return wattle.nil();
    return optString(cmark_node_get_fence_info(h.node));
}

fn setFenceInfo(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    const h = try getHandle(argv, 0);
    try setString(h.node, try wattle.getBytes(argv, 1), &cmark_node_set_fence_info, "fence info");
    return argv[0];
}

fn url(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    return optString(cmark_node_get_url((try getHandle(argv, 0)).node));
}

fn setUrl(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    const h = try getHandle(argv, 0);
    try setString(h.node, try wattle.getBytes(argv, 1), &cmark_node_set_url, "url");
    return argv[0];
}

fn title(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    return optString(cmark_node_get_title((try getHandle(argv, 0)).node));
}

fn setTitle(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    const h = try getHandle(argv, 0);
    try setString(h.node, try wattle.getBytes(argv, 1), &cmark_node_set_title, "title");
    return argv[0];
}

fn headingLevel(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    const level = cmark_node_get_heading_level((try getHandle(argv, 0)).node);
    return if (level == 0) wattle.nil() else wattle.number(@floatFromInt(level));
}

/// Applies one of cmark's tree edits to two nodes of the same document.
fn edit(argv: []wattle.Value, op: *const fn (*Node, *Node) callconv(.c) c_int, what: []const u8) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 2);
    const a = try getHandle(argv, 0);
    const b = try getHandle(argv, 1);
    if (a.doc != b.doc) return wattle.panic("cannot move a node to another document");
    if (cmark_node_get_type(b.node) == document_type) return wattle.panic("cannot move a :document node");
    if (op(a.node, b.node) == 0)
        return wattle.panicFormat("cannot {s} a :{s} node there", .{ what, wattle.toKeyword(typeName(b.node)) orelse "unknown" });
    return argv[0];
}

fn insertBefore(argv: []wattle.Value) wattle.Error!wattle.Value {
    return edit(argv, &cmark_node_insert_before, "insert");
}

fn insertAfter(argv: []wattle.Value) wattle.Error!wattle.Value {
    return edit(argv, &cmark_node_insert_after, "insert");
}

fn appendChild(argv: []wattle.Value) wattle.Error!wattle.Value {
    return edit(argv, &cmark_node_append_child, "append");
}

fn prependChild(argv: []wattle.Value) wattle.Error!wattle.Value {
    return edit(argv, &cmark_node_prepend_child, "prepend");
}

/// Implements `(cmark/unlink! node)`.
fn unlink(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    const h = try getHandle(argv, 0);
    if (h.node == h.doc.root) return wattle.panic("cannot unlink a :document node");
    cmark_node_unlink(h.node);
    try adopt(h.doc, h.node);
    return argv[0];
}

fn defs(env: *wattle.Env) wattle.Error!void {
    wattle.nfuns(env, "cmark", &.{
        wattle.reg("parse", &parse, "(cmark/parse text options)", "Parses the Markdown text with the cmark option bits options and returns the document node."),
        wattle.reg("render-html", &renderHtml, "(cmark/render-html node options)", "Renders node and its descendants as HTML with the cmark option bits options."),
        wattle.reg("new", &new, "(cmark/new node type)", "Returns a new node of type, a keyword such as :text, in the document of node. It has no parent."),
        wattle.reg("nodes", &nodes, "(cmark/nodes node)", "Returns an array of node and its descendants, in the order of the document."),
        wattle.reg("children", &children, "(cmark/children node)", "Returns an array of the children of node."),
        wattle.reg("parent", &parent, "(cmark/parent node)", "Returns the parent of node, or nil."),
        wattle.reg("type", &typeOf, "(cmark/type node)", "Returns the type of node as a keyword, such as :paragraph or :footnote-reference."),
        wattle.reg("same?", &same, "(cmark/same? a b)", "Returns true if the handles a and b are to the same node."),
        wattle.reg("literal", &literal, "(cmark/literal node)", "Returns the text of a :text, :code, :code-block, :html-block, :html-inline or :footnote-reference node, or nil."),
        wattle.reg("set-literal!", &setLiteral, "(cmark/set-literal! node text)", "Sets the text of node and returns node."),
        wattle.reg("fence-info", &fenceInfo, "(cmark/fence-info node)", "Returns the info string of a :code-block node, or nil."),
        wattle.reg("set-fence-info!", &setFenceInfo, "(cmark/set-fence-info! node info)", "Sets the info string of a :code-block node and returns node."),
        wattle.reg("url", &url, "(cmark/url node)", "Returns the URL of a :link or :image node, or nil."),
        wattle.reg("set-url!", &setUrl, "(cmark/set-url! node url)", "Sets the URL of a :link or :image node and returns node."),
        wattle.reg("title", &title, "(cmark/title node)", "Returns the title of a :link or :image node, or nil."),
        wattle.reg("set-title!", &setTitle, "(cmark/set-title! node title)", "Sets the title of a :link or :image node and returns node."),
        wattle.reg("heading-level", &headingLevel, "(cmark/heading-level node)", "Returns the level of a :heading node, or nil."),
        wattle.reg("insert-before!", &insertBefore, "(cmark/insert-before! node sibling)", "Moves sibling to before node and returns node."),
        wattle.reg("insert-after!", &insertAfter, "(cmark/insert-after! node sibling)", "Moves sibling to after node and returns node."),
        wattle.reg("append-child!", &appendChild, "(cmark/append-child! node child)", "Moves child to the end of the children of node and returns node."),
        wattle.reg("prepend-child!", &prependChild, "(cmark/prepend-child! node child)", "Moves child to the start of the children of node and returns node."),
        wattle.reg("unlink!", &unlink, "(cmark/unlink! node)", "Removes node from its parent and returns node. It is freed with its document."),
    });
}

comptime {
    wattle.entry(defs);
}
