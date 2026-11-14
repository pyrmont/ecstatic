/* Written by hand in place of the header that CMake's GenerateExportHeader
   writes. cmark-gfm is compiled into a static executable, so nothing is
   exported from a shared library and the macros are empty. */
#ifndef CMARK_GFM_EXPORT_H
#define CMARK_GFM_EXPORT_H

#define CMARK_GFM_EXPORT
#define CMARK_GFM_NO_EXPORT

#ifndef CMARK_GFM_DEPRECATED
#  define CMARK_GFM_DEPRECATED __attribute__ ((__deprecated__))
#endif

#endif
