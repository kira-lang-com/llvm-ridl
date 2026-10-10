; The RIDL calling convention's structural rules (KLF-RIDL section 22.2): the
; context register and the error register are single named registers, so at most
; one of each may appear, and both belong to `ridlcc` alone.
;
; RUN: not llvm-as %s -o /dev/null 2>&1 | FileCheck %s

; A valid `ridlcc` function may carry both, and the checks below are all the
; diagnostics this module should produce.
; CHECK: Cannot have multiple 'ridlcontext' parameters!
; CHECK: ptr @two_contexts
; CHECK: Cannot have multiple 'ridlerror' parameters!
; CHECK: ptr @two_errors
; CHECK: 'ridlerror' is only valid on a 'ridlcc' function!
; CHECK: ptr @error_on_c
; CHECK: 'ridlcontext' is only valid on a 'ridlcc' function!
; CHECK: ptr @context_on_c
; CHECK: 'ridlerror' is only valid on a 'ridlcc' function!
; CHECK: call i32 @plain

declare ridlcc i32 @ok(ptr ridlcontext %ctx, i32 %v, ptr ridlerror %err)

declare ridlcc i32 @two_contexts(ptr ridlcontext %a, ptr ridlcontext %b)

declare ridlcc i32 @two_errors(ptr ridlerror %a, ptr ridlerror %b)

declare i32 @error_on_c(ptr ridlerror %e)

declare i32 @context_on_c(ptr ridlcontext %c)

; The same rules hold at a call site, where the convention is the call's.
declare i32 @plain(ptr)

define i32 @call_on_c() {
  %r = call i32 @plain(ptr ridlerror null)
  ret i32 %r
}