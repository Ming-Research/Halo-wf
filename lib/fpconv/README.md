# fpconv

A Whitefoot port of fpconv's `fpconv_dtoa`, the conversion Redis 7.2.16 links
from `deps/fpconv` to write a double as text: Florian Loitsch's Grisu2 digit
generation with no exact fallback, fpconv's table of 87 cached powers of ten,
and its layout. The package names no host: Halo's test host and Firn both
bind it by path, so the two write the same bytes.

## API

One module, `fpconv::dtoa` ([module.wfm](dtoa/module.wfm) owns the exact
contract):

```text
format_double(value: f64, out: &[u8]) -> length: u64
```

It writes into the first `length` bytes of `out`, which must hold 32, as
Halo's `format_number` does.

- Digits: Grisu2's digits read back exactly but are not always the shortest
  that do; 1e23 is `99999999999999990000000`, not `1e+23`.
- Layout, with K the power of ten of the last digit and E that of the first:
  an integer and K zeros when K is 0 to 7; a decimal with a point (`0.00001`,
  `1234.5`) when K is from -6 to -1 or E is from -3 to 3; otherwise one digit,
  a point and the rest, then `e+` or `e-` and E with no padding (`1e+100`,
  `1e-7`).
- Specials, as `fpconv_dtoa` writes them: a set sign bit writes `-` first,
  then `0` for either zero, `inf` for an infinity and `nan` for a NaN, so a
  negative NaN, such as x86-64's default NaN that 0/0 gives, is `-nan`.

The caller applies its own rules around the conversion, and Halo's test host
applies Redis's in
[host.wf](../../research/experiments/halo-e2e/test/host.wf). For a double
reply, Redis's `d2string` writes every NaN as `nan` whatever its sign, and
the infinities and the zeros, itself; it writes an integral value no larger
in magnitude than 2^62 as an integer (`double2ll`), and only then calls
fpconv. For a number passed to `redis.call`, `luaArgsToRedisArgv` applies the
same integer rule and otherwise calls fpconv directly, so a negative NaN
stays `-nan` and -0 becomes `0`.

## Oracle table

[redis-7.2.16.tsv](../../research/experiments/redis-double-text/redis-7.2.16.tsv)
holds one row per double, by its bit pattern, with what redis-server 7.2.16
wrote for it:

- `double_reply`: the RESP2 reply to `EVAL "return {double=x}"`;
- `call_argument`: the value `redis.call('SET', k, x)` stored, read back
  with GET;
- `family`: how the value was chosen: `case` for hand-picked values, then
  `random-bits`, `dec6`, `dec3-big`, `uniform01`, `layout-grid`,
  `integer-edge`, and `special` for both NaNs and both infinities.

[record.py](../../research/experiments/redis-double-text/record.py) records
it. The oracle-reference workflow
([oracle-reference.yml](../../.github/workflows/oracle-reference.yml)) runs it
against Redis 7.2.16 built from source on x86-64 Linux with glibc, as it
records the oracle replies, and uploads the table with them and its
difference from the committed one; a person reviews the difference and
commits the table. The recorder sends each double to the script as its 8
bytes, so every NaN keeps its sign, and requires the number the script passed
to `redis.call` to have the same bits.

The values are the ones Whitefoot's first float-text experiment measured
([Whitefoot CI run 38236089638](https://github.com/Ming-Research/Whitefoot/actions/runs/38236089638),
on x86-64 Linux with glibc 2.39 and gcc 13.3.0), plus the four special
values. That run measured 18,281 values, of which 18,231 are distinct. Every
nonzero value outside the integer rule matched a reconstruction of
`fpconv_dtoa`, and 355 of those 16,922 values (351 of the 16,890 distinct
ones) have other digits than the exact shortest.

## Check

`make double-text`, part of the gate's core group, runs
[check.py](../../research/experiments/redis-double-text/check.py). It first
requires the table's row count and SHA-256 digest to equal the ones it pins,
so a table recorded again enters the gate only with both updated. Halo's
end-to-end test program, run with `--double-text`, writes both texts of every
row with the test host's rules, and each must equal the table byte for byte.
Before that, the runner checks that the table rejects an exact-shortest
formatter (it has other digits on 351 rows, 1e23 among them) and that its
comparison reports a single changed text.

## License

The port keeps fpconv's Boost Software License 1.0 notice in
[dtoa/LICENSE.md](dtoa/LICENSE.md).
