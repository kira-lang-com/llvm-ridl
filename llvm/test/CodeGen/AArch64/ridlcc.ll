; The RIDL calling convention on aarch64 (KLF-RIDL section 22).
;
; Section 22.2: integer arguments in x0 to x7, float arguments in v0 to v7,
; direct results in x0 to x3 and v0 to v3, the indirect result in x8, the
; context register in x20 and the error register in x21.
;
; RIDL owns these registers. They are not `swiftself` and `swifterror`, and the
; error register takes no part in the exception-handling model: it carries a
; pointer to a RIDL box under section 22.5.
;
; RUN: llc -mtriple=aarch64-unknown-linux-gnu %s -o - | FileCheck %s
; RUN: llc -mtriple=aarch64-apple-ios %s -o - | FileCheck %s --check-prefix=DARWIN

; Ordinary arguments and results are placed by the base standard, AAPCS64 (22.1).
; CHECK-LABEL: ridl_sum:
; CHECK: add x0, x0, x1

define ridlcc i64 @ridl_sum(i64 %a, i64 %b) {
entry:
  %r = add i64 %a, %b
  ret i64 %r
}

; `ridl_sum` declares no `ridlerror` parameter, so it is not a failing function
; and section 22.5's protocol does not apply: x21 is left alone.
; CHECK-LABEL: ridl_check:
; CHECK-NOT: x21
; CHECK: bl ridl_sum

define ridlcc i64 @ridl_check(i64 %x) {
entry:
  %r = call ridlcc i64 @ridl_sum(i64 %x, i64 1)
  ret i64 %r
}

; A failing function is one that takes the error register (22.2). Section 22.5
; has the caller zero x21 before the call; the callee leaves it zero on success
; and stores a pointer to a RIDL box on failure. x21 is not preserved, so it is
; spilled across the call.
; CHECK-LABEL: ridl_check_failing:
; CHECK: mov x21, xzr
; CHECK: bl ridl_fails

declare ridlcc i64 @ridl_fails(i64 %x, ptr ridlerror %err)

define ridlcc i64 @ridl_check_failing(i64 %x) {
entry:
  %r = call ridlcc i64 @ridl_fails(i64 %x, ptr ridlerror inttoptr (i64 0 to ptr))
  ret i64 %r
}

; Section 22.2: the context register is x20 and is callee-saved, so it is spilled
; and given a CFI offset across the call. The error register is x21, is not
; preserved, and here receives the box pointer the caller passes.
; CHECK-LABEL: ridl_use_specials:
; CHECK: .cfi_offset w20, -8
; CHECK: .cfi_offset w21, -16
; CHECK: add x21, sp, #8
; CHECK: mov x20, x0
; CHECK: bl ridl_with_specials

declare ridlcc i64 @ridl_with_specials(ptr ridlcontext %ctx, i64 %v, ptr ridlerror %err)

define ridlcc i64 @ridl_use_specials(ptr %ctx, i64 %v) {
entry:
  %slot = alloca ptr
  store ptr null, ptr %slot
  %r = call ridlcc i64 @ridl_with_specials(ptr ridlcontext %ctx, i64 %v, ptr ridlerror %slot)
  ret i64 %r
}

; Floats go in v0 to v7 and come back in v0 to v3.
; CHECK-LABEL: ridl_floats:
; CHECK: fadd d0, d0, d1

define ridlcc double @ridl_floats(double %a, double %b, i64 %n) {
entry:
  %s = fadd double %a, %b
  %c = fptosi double %s to i64
  %r = sitofp i64 %n to double
  %sum = fadd double %s, %r
  ret double %sum
}

; On Darwin the base is the Apple variant (22.1), and both RIDL registers are
; unchanged: section 22.2 gives them on "aarch64 (all OS)".
; DARWIN-LABEL: ridl_use_specials:
; DARWIN: add x21, sp, #8
; DARWIN: mov x20, x0