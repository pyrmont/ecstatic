//! Oniguruma scanners for the TextMate engine.
//!
//! A scanner holds a list of regexes and finds the one whose match starts
//! earliest, with the earlier regex winning a tie, as `vscode-oniguruma`'s
//! `OnigScanner` does. Regexes are compiled with Oniguruma's default syntax and
//! `ONIG_OPTION_CAPTURE_GROUP`, the settings `vscode-oniguruma` uses.
//!
//! Each regex's last result is kept for the text it was found in. A later
//! search of the same text from a position at or before that match reuses it,
//! since the match cannot change, unless the regex contains `\G`, whose match
//! depends on where the search starts.

const wattle = @import("wattle");

const OnigRegex = ?*anyopaque;
const OnigEncoding = *anyopaque;

const OnigRegion = extern struct {
    allocated: c_int,
    num_regs: c_int,
    beg: [*]c_int,
    end: [*]c_int,
    history_root: ?*anyopaque,
};

const OnigErrorInfo = extern struct {
    enc: ?OnigEncoding,
    par: ?[*]u8,
    par_end: ?[*]u8,
};

const ONIG_OPTION_NONE: c_uint = 0;
const ONIG_OPTION_CAPTURE_GROUP: c_uint = 1 << 8;
const ONIG_MAX_ERROR_MESSAGE_LEN = 90;

extern var OnigEncodingUTF8: anyopaque;
extern var OnigDefaultSyntax: *anyopaque;
extern fn onig_initialize(encs: [*]OnigEncoding, n: c_int) c_int;
extern fn onig_new(reg: *OnigRegex, pattern: [*]const u8, pattern_end: [*]const u8, option: c_uint, enc: OnigEncoding, syntax: *anyopaque, einfo: ?*OnigErrorInfo) c_int;
extern fn onig_free(reg: OnigRegex) void;
extern fn onig_region_new() ?*OnigRegion;
extern fn onig_region_free(region: *OnigRegion, free_self: c_int) void;
extern fn onig_search(reg: OnigRegex, str: [*]const u8, end: [*]const u8, start: [*]const u8, range: [*]const u8, region: *OnigRegion, option: c_uint) c_int;
extern fn onig_error_code_to_str(s: [*]u8, err_code: c_int, ...) c_int;

/// The payload of a scanner. Each array has `n` elements, one for each regex.
/// `regexes` holds null for a regex that could not be compiled, which never
/// matches. `searched` is the position of the last search of `text` with each
/// regex, or -1, and `found` is where that search's match starts, or -1.
const Scanner = struct {
    n: usize,
    regexes: [*]OnigRegex,
    regions: [*]*OnigRegion,
    anchored: [*]bool,
    searched: [*]isize,
    found: [*]isize,
    text: wattle.Value,
};

fn scannerGc(self: *Scanner, _: usize) void {
    for (0..self.n) |i| {
        if (self.regexes[i] != null) onig_free(self.regexes[i]);
        onig_region_free(self.regions[i], 1);
    }
    wattle.free(self.regexes[0..self.n]);
    wattle.free(self.regions[0..self.n]);
    wattle.free(self.anchored[0..self.n]);
    wattle.free(self.searched[0..self.n]);
    wattle.free(self.found[0..self.n]);
}

fn scannerMark(self: *Scanner, _: usize) void {
    wattle.mark(self.text);
}

const scanner_type = wattle.define(Scanner, .{
    .name = "onig/scanner",
    .gc = scannerGc,
    .gcmark = scannerMark,
});

/// Compiles `pattern`. Returns the regex, or the error code if Oniguruma
/// rejects it, with `einfo` filled in.
fn compile(pattern: []const u8, einfo: *OnigErrorInfo) union(enum) { ok: OnigRegex, err: c_int } {
    var reg: OnigRegex = null;
    const r = onig_new(&reg, pattern.ptr, pattern.ptr + pattern.len, ONIG_OPTION_CAPTURE_GROUP, &OnigEncodingUTF8, OnigDefaultSyntax, einfo);
    return if (r == 0) .{ .ok = reg } else .{ .err = r };
}

/// Returns true if `pattern` contains `\G`.
fn hasG(pattern: []const u8) bool {
    var i: usize = 0;
    while (i + 1 < pattern.len) : (i += 1) {
        if (pattern[i] == '\\') {
            if (pattern[i + 1] == 'G') return true;
            i += 1;
        }
    }
    return false;
}

/// Implements `(onig/error pattern)`.
fn errorOf(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    const pattern = try wattle.getBytes(argv, 0);
    var einfo: OnigErrorInfo = .{ .enc = null, .par = null, .par_end = null };
    switch (compile(pattern, &einfo)) {
        .ok => |reg| {
            onig_free(reg);
            return wattle.nil();
        },
        .err => |code| {
            var buf: [ONIG_MAX_ERROR_MESSAGE_LEN]u8 = undefined;
            const len = onig_error_code_to_str(&buf, code, &einfo);
            return wattle.string(buf[0..@intCast(len)]);
        },
    }
}

/// Implements `(onig/scanner patterns)`.
fn newScanner(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 1);
    var patterns = try wattle.getIndexed(argv, 0);
    const n = patterns.len;
    const regexes = wattle.alloc(OnigRegex, n) orelse return wattle.panic("out of memory");
    const regions = wattle.alloc(*OnigRegion, n) orelse return wattle.panic("out of memory");
    const anchored = wattle.alloc(bool, n) orelse return wattle.panic("out of memory");
    const searched = wattle.alloc(isize, n) orelse return wattle.panic("out of memory");
    const found = wattle.alloc(isize, n) orelse return wattle.panic("out of memory");
    for (0..n) |i| {
        const item = (try patterns.get(i)).?;
        const pattern = wattle.bytesView(item) orelse return wattle.panic("expected a string pattern");
        var einfo: OnigErrorInfo = .{ .enc = null, .par = null, .par_end = null };
        regexes[i] = switch (compile(pattern, &einfo)) {
            .ok => |reg| reg,
            .err => null,
        };
        regions[i] = onig_region_new() orelse return wattle.panic("out of memory");
        anchored[i] = hasG(pattern);
        searched[i] = -1;
        found[i] = -1;
    }
    const s = wattle.new(Scanner, &scanner_type, null);
    s.* = .{
        .n = n,
        .regexes = regexes.ptr,
        .regions = regions.ptr,
        .anchored = anchored.ptr,
        .searched = searched.ptr,
        .found = found.ptr,
        .text = wattle.nil(),
    };
    return wattle.abstract(s);
}

/// Implements `(onig/scan scanner text pos)`.
fn scan(argv: []wattle.Value) wattle.Error!wattle.Value {
    try wattle.fixarity(argv, 3);
    const s = try wattle.getAbstract(Scanner, argv, 0, &scanner_type);
    const text = try wattle.getBytes(argv, 1);
    const pos = try wattle.getSize(argv, 2);
    if (pos > text.len) return wattle.nil();
    // A string cannot change, so results found in it can be reused while it is
    // the scanner's text, which marking keeps alive.
    const previous = wattle.bytesView(s.text);
    const same = wattle.isString(argv[1]) and previous != null and
        previous.?.ptr == text.ptr and previous.?.len == text.len;
    if (!same) {
        for (0..s.n) |i| s.searched[i] = -1;
        s.text = if (wattle.isString(argv[1])) argv[1] else wattle.nil();
    }
    const p: isize = @intCast(pos);
    var best: ?usize = null;
    var best_start: isize = -1;
    for (0..s.n) |i| {
        if (s.regexes[i] == null) continue;
        const cached = !s.anchored[i] and s.searched[i] >= 0 and s.searched[i] <= p and
            (s.found[i] == -1 or s.found[i] >= p);
        if (!cached) {
            const r = onig_search(s.regexes[i], text.ptr, text.ptr + text.len, text.ptr + pos, text.ptr + text.len, s.regions[i], ONIG_OPTION_NONE);
            s.searched[i] = p;
            s.found[i] = if (r >= 0) r else -1;
        }
        const start = s.found[i];
        if (start >= 0 and (best == null or start < best_start)) {
            best = i;
            best_start = start;
            if (start == p) break;
        }
    }
    const i = best orelse return wattle.nil();
    const region = s.regions[i];
    const count: usize = @intCast(region.num_regs);
    const caps = wattle.alloc(wattle.Value, count) orelse return wattle.panic("out of memory");
    defer wattle.free(caps);
    for (0..count) |j| {
        caps[j] = if (region.beg[j] < 0) wattle.nil() else wattle.tuple(&.{
            wattle.number(@floatFromInt(region.beg[j])),
            wattle.number(@floatFromInt(region.end[j])),
        });
    }
    return wattle.tuple(&.{ wattle.number(@floatFromInt(i)), wattle.tuple(caps) });
}

fn defs(env: *wattle.Env) wattle.Error!void {
    var encs = [_]OnigEncoding{&OnigEncodingUTF8};
    if (onig_initialize(&encs, 1) != 0) return wattle.panic("could not initialize Oniguruma");
    wattle.nfuns(env, "onig", &.{
        wattle.reg("error", &errorOf, "(onig/error pattern)",
            "Returns the message for the error in the regex pattern, or nil if it compiles."),
        wattle.reg("scanner", &newScanner, "(onig/scanner patterns)",
            "Returns a scanner for the regexes in patterns. A pattern that does not compile never matches."),
        wattle.reg("scan", &scan, "(onig/scan scanner text pos)",
            "Returns the index of the regex in scanner whose match in text, at or after pos, starts earliest, " ++
            "and a tuple of the [start end] of each group, with nil for a group that did not take part. " ++
            "Returns nil if none matches."),
    });
}

comptime {
    wattle.entry(defs);
}
