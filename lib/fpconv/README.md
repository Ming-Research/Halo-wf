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
format_double(value: f64, signed_nan: Bool, out: &[u8]) -> length: u64
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
- Specials: a set sign bit writes `-` first, then `0` for either zero and
  `inf` for an infinity. A NaN is `nan`, signed when `signed_nan` is true, as
  fpconv itself writes it (`-nan` for x86-64's default NaN), and unsigned
  when it is false, as Redis's `d2string` normalizes it.

The caller applies its own rules around the conversion. Redis writes an
integral value no larger in magnitude than 2^62 as an integer (`double2ll`)
before calling fpconv, and `d2string` handles NaN, the infinities and the
zeros itself; Halo's test host does both in
[host.wf](../../research/experiments/halo-e2e/test/host.wf).

## Oracle table

[redis-7.2.16.tsv](../../research/experiments/redis-double-text/redis-7.2.16.tsv)
holds 18,231 doubles, each by its bit pattern, with what redis-server 7.2.16
(x86-64 Linux, glibc 2.39, gcc 13.3.0) wrote for it, measured by
[Whitefoot CI run 38236089638](https://github.com/Ming-Research/Whitefoot/actions/runs/38236089638):

- `double_reply`: the RESP2 reply to `EVAL "return {double=x}"`;
- `call_argument`: the value `redis.call('SET', k, x)` stored, read back
  with GET;
- `family`: the run's name for how the value was chosen: `case` for
  hand-picked values, then `random-bits`, `dec6`, `dec3-big`, `uniform01`,
  `layout-grid` and `integer-edge`.

The run measured 18,281 values, of which 18,231 are distinct. Every nonzero
value outside the integer rule matched a reconstruction of `fpconv_dtoa`, and
355 of those 16,922 values (351 of the table's 16,890 distinct ones) have
other digits than the exact shortest. The table holds no NaN or infinity;
Halo's oracle scripts `number-argument-format` and `double-reply-table` cover
them.

## Check

`make double-text`, part of the gate's core group, runs
[check.py](../../research/experiments/redis-double-text/check.py): Halo's
end-to-end test program, run with `--double-text`, writes both texts of every
row with the test host's rules, and each must equal the table byte for byte.
Four NaN and infinity probes, whose texts are read from Redis's source rather
than measured, are checked the same way. Before that, the runner checks that
the table rejects an exact-shortest formatter (it has other digits on 351
rows, 1e23 among them) and that its comparison reports a single changed text.

## License

The port keeps fpconv's Boost Software License 1.0 notice in
[dtoa/LICENSE.md](dtoa/LICENSE.md).
