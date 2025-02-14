;
; Copyright (c) 2016, Alliance for Open Media. All rights reserved
;
; This source code is subject to the terms of the BSD 2 Clause License and
; the Alliance for Open Media Patent License 1.0. If the BSD 2 Clause License
; was not distributed with this source code in the LICENSE file, you can
; obtain it at www.aomedia.org/license/software. If the Alliance for Open
; Media Patent License 1.0 was not distributed with this source code in the
; PATENTS file, you can obtain it at www.aomedia.org/license/patent.
;

;


%include "aom_ports/x86_abi_support.asm"

SECTION_TEXT
global sym(aom_reset_mmx_state) PRIVATE
sym(aom_reset_mmx_state):
    emms
    ret


%if LIBAOM_YASM_WIN64
global sym(aom_winx64_fldcw) PRIVATE
sym(aom_winx64_fldcw):
    sub   rsp, 8
    mov   [rsp], rcx ; win x64 specific
    fldcw [rsp]
    add   rsp, 8
    ret


global sym(aom_winx64_fstcw) PRIVATE
sym(aom_winx64_fstcw):
    sub   rsp, 8
    fstcw [rsp]
    mov   rax, [rsp]
    add   rsp, 8
    ret
%endif
