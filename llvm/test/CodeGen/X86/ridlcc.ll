; The RIDL calling convention on x86-64 (KLF-RIDL section 22).
;
; Section 22.2 for x86-64 System V: integer arguments in rdi rsi rdx rcx r8 r9,
; float arguments in xmm0 to xmm7, direct results in rax rdx rcx r8 and xmm0 to
; xmm3, the indirect result in rax, the context register in r13 and the error
; register in r12.
;
; RIDL owns both registers. They are not `swiftself` and `swifterror`: the error
; register carries a pointer to a RIDL box under 22.5 and takes no part in the
; exception-handling model.
;
; RUN: llc -mtriple=x86_64-unknown-linux-gnu %s -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc %s -o - | FileCheck %s --check-prefix=WIN

; Ordinary arguments are placed by the SysV base (22.1): the first two integer
; arguments arrive in rdi and rsi, and the result goes to rax.
; CHECK-LABEL: ridl_sum:
; CHECK: leaq (%rdi,%rsi), %rax
; CHECK: retq

define ridlcc i64 @ridl_sum(i64 %a, i64 %b) {
entry:
  %r = add i64 %a, %b
  ret i64 %r
}

; `ridl_sum` declares no `ridlerror` parameter, so it is not a failing function
; and section 22.5 does not apply: neither RIDL register is set up for the call.
; CHECK-LABEL: ridl_check:
; CHECK-NOT: r12
; CHECK-NOT: r13
; CHECK: callq ridl_sum

define ridlcc i64 @ridl_check(i64 %x) {
entry:
  %r = call ridlcc i64 @ridl_sum(i64 %x, i64 1)
  ret i64 %r
}

; A failing function is one that takes the error register (22.2). Section 22.5
; has the caller zero r12 before the call. r12 is not preserved, so it is spilled
; with a CFI offset across it.
; CHECK-LABEL: ridl_check_failing:
; CHECK: xorl %r12d, %r12d
; CHECK: callq ridl_fails

declare ridlcc i64 @ridl_fails(i64 %x, ptr ridlerror %err)

define ridlcc i64 @ridl_check_failing(i64 %x) {
entry:
  %r = call ridlcc i64 @ridl_fails(i64 %x, ptr ridlerror null)
  ret i64 %r
}

; Section 22.2: the context register is r13 and is callee-saved, the error
; register is r12 and is not. Both take their value from the ridlcontext and
; ridlerror parameters, which are RIDL's own and not `swiftself`/`swifterror`.
; CHECK-LABEL: ridl_use_specials:
; CHECK: .cfi_offset %r12, -24
; CHECK: .cfi_offset %r13, -16
; CHECK: movq %rsp, %r12
; CHECK: movq %rdi, %r13
; CHECK: callq ridl_with_specials

declare ridlcc i64 @ridl_with_specials(ptr ridlcontext %ctx, i64 %v, ptr ridlerror %err)

define ridlcc i64 @ridl_use_specials(ptr %ctx, i64 %v) {
entry:
  %slot = alloca ptr
  store ptr null, ptr %slot
  %r = call ridlcc i64 @ridl_with_specials(ptr ridlcontext %ctx, i64 %v, ptr ridlerror %slot)
  ret i64 %r
}

; On the Win64 base the argument registers change to rcx and rdx (22.2), while
; r13 and r12 are still RIDL's context and error registers, because 22.2 gives
; them per architecture rather than per OS.
; WIN-LABEL: ridl_sum:
; WIN: leaq (%rcx,%rdx), %rax
; WIN: retq