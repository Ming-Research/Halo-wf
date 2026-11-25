# Double text

How a host writes the text Redis 7.2.16 gives a double, through the general package `lib/fpconv`.

### decision fpconv-ports-fpconv-dtoa-as-is
`lib/fpconv` is a pure port of Redis's `fpconv_dtoa`, Grisu2 with no exact fallback, that names no host; each host applies Redis's reply rules around it.
- rejected: an agent proposed the shortest form of Whitefoot's standard library; the owner rejected it, because the owner ruled that form follows the exact definition, so it writes 1e+23 where Redis writes 99999999999999990000000, and 355 of 16,922 values differ (data: `lib/fpconv/README.md`).
- rejected: an agent proposed a copy of the conversion in each host; the owner rejected it, because Halo's test host and Firn would have to keep two ports of one algorithm byte-identical, each with its own check against the same table.
- rejected: an agent proposed putting Redis's integer rule and `d2string`'s special values inside the package; the owner rejected it, because they are Redis's reply rules rather than fpconv's, and a package that names no host stays usable as the codec packages are.
- rejected: an agent proposed a package parameter that chooses whether a NaN's sign is written; the owner rejected it, because it carries a reply rule into the general package, which would then no longer write what `fpconv_dtoa` writes.
