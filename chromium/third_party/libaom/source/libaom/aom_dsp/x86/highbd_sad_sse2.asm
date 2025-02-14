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

%include "third_party/x86inc/x86inc.asm"

SECTION_TEXT

%macro HIGH_SAD_FN 4
%if %4 == 0
%if %3 == 5
cglobal highbd_sad%1x%2, 4, %3, 7, src, src_stride, ref, ref_stride, n_rows
%else ; %3 == 7
cglobal highbd_sad%1x%2, 4, %3, 7, src, src_stride, ref, ref_stride, \
                            src_stride3, ref_stride3, n_rows
%endif ; %3 == 5/7
%else ; avg
%if %3 == 5
cglobal highbd_sad%1x%2_avg, 5, 1 + %3, 7, src, src_stride, ref, ref_stride, \
                                    second_pred, n_rows
%else ; %3 == 7
cglobal highbd_sad%1x%2_avg, 5, ARCH_X86_64 + %3, 7, src, src_stride, \
                                              ref, ref_stride, \
                                              second_pred, \
                                              src_stride3, ref_stride3
%if ARCH_X86_64
%define n_rowsd r7d
%else ; x86-32
%define n_rowsd dword r0m
%endif ; x86-32/64
%endif ; %3 == 5/7
%endif ; avg/sad
  movsxdifnidn src_strideq, src_strided
  movsxdifnidn ref_strideq, ref_strided
%if %3 == 7
  lea         src_stride3q, [src_strideq*3]
  lea         ref_stride3q, [ref_strideq*3]
%endif ; %3 == 7
; convert src, ref & second_pred to short ptrs (from byte ptrs)
  shl                 srcq, 1
  shl                 refq, 1
%if %4 == 1
  shl         second_predq, 1
%endif
%endmacro

; unsigned int aom_highbd_sad64x{16,32,64}_sse2(uint8_t *src, int src_stride,
;                                    uint8_t *ref, int ref_stride);
%macro HIGH_SAD64XN 1-2 0
  HIGH_SAD_FN 64, %1, 5, %2
  mov              n_rowsd, %1
  pxor                  m0, m0
  pxor                  m6, m6

.loop:
  ; first half of each row
  movu                  m1, [refq]
  movu                  m2, [refq+16]
  movu                  m3, [refq+32]
  movu                  m4, [refq+48]
%if %2 == 1
  pavgw                 m1, [second_predq+mmsize*0]
  pavgw                 m2, [second_predq+mmsize*1]
  pavgw                 m3, [second_predq+mmsize*2]
  pavgw                 m4, [second_predq+mmsize*3]
  lea         second_predq, [second_predq+mmsize*4]
%endif
  mova                  m5, [srcq]
  psubusw               m5, m1
  psubusw               m1, [srcq]
  por                   m1, m5
  mova                  m5, [srcq+16]
  psubusw               m5, m2
  psubusw               m2, [srcq+16]
  por                   m2, m5
  mova                  m5, [srcq+32]
  psubusw               m5, m3
  psubusw               m3, [srcq+32]
  por                   m3, m5
  mova                  m5, [srcq+48]
  psubusw               m5, m4
  psubusw               m4, [srcq+48]
  por                   m4, m5
  paddw                 m1, m2
  paddw                 m3, m4
  movhlps               m2, m1
  movhlps               m4, m3
  paddw                 m1, m2
  paddw                 m3, m4
  punpcklwd             m1, m6
  punpcklwd             m3, m6
  paddd                 m0, m1
  paddd                 m0, m3
  ; second half of each row
  movu                  m1, [refq+64]
  movu                  m2, [refq+80]
  movu                  m3, [refq+96]
  movu                  m4, [refq+112]
%if %2 == 1
  pavgw                 m1, [second_predq+mmsize*0]
  pavgw                 m2, [second_predq+mmsize*1]
  pavgw                 m3, [second_predq+mmsize*2]
  pavgw                 m4, [second_predq+mmsize*3]
  lea         second_predq, [second_predq+mmsize*4]
%endif
  mova                  m5, [srcq+64]
  psubusw               m5, m1
  psubusw               m1, [srcq+64]
  por                   m1, m5
  mova                  m5, [srcq+80]
  psubusw               m5, m2
  psubusw               m2, [srcq+80]
  por                   m2, m5
  mova                  m5, [srcq+96]
  psubusw               m5, m3
  psubusw               m3, [srcq+96]
  por                   m3, m5
  mova                  m5, [srcq+112]
  psubusw               m5, m4
  psubusw               m4, [srcq+112]
  por                   m4, m5
  paddw                 m1, m2
  paddw                 m3, m4
  movhlps               m2, m1
  movhlps               m4, m3
  paddw                 m1, m2
  paddw                 m3, m4
  punpcklwd             m1, m6
  punpcklwd             m3, m6
  lea                 refq, [refq+ref_strideq*2]
  paddd                 m0, m1
  lea                 srcq, [srcq+src_strideq*2]
  paddd                 m0, m3

  dec              n_rowsd
  jg .loop

  movhlps               m1, m0
  paddd                 m0, m1
  punpckldq             m0, m6
  movhlps               m1, m0
  paddd                 m0, m1
  movd                 eax, m0
  RET
%endmacro

INIT_XMM sse2
HIGH_SAD64XN 64 ; highbd_sad64x64_sse2
HIGH_SAD64XN 32 ; highbd_sad64x32_sse2
HIGH_SAD64XN 64, 1 ; highbd_sad64x64_avg_sse2
HIGH_SAD64XN 32, 1 ; highbd_sad64x32_avg_sse2
HIGH_SAD64XN 16 ; highbd_sad_64x16_sse2
HIGH_SAD64XN 16, 1 ; highbd_sad_64x16_avg_sse2

; unsigned int aom_highbd_sad32x{16,32,64}_sse2(uint8_t *src, int src_stride,
;                                    uint8_t *ref, int ref_stride);
%macro HIGH_SAD32XN 1-2 0
  HIGH_SAD_FN 32, %1, 5, %2
  mov              n_rowsd, %1
  pxor                  m0, m0
  pxor                  m6, m6

.loop:
  movu                  m1, [refq]
  movu                  m2, [refq+16]
  movu                  m3, [refq+32]
  movu                  m4, [refq+48]
%if %2 == 1
  pavgw                 m1, [second_predq+mmsize*0]
  pavgw                 m2, [second_predq+mmsize*1]
  pavgw                 m3, [second_predq+mmsize*2]
  pavgw                 m4, [second_predq+mmsize*3]
  lea         second_predq, [second_predq+mmsize*4]
%endif
  mova                  m5, [srcq]
  psubusw               m5, m1
  psubusw               m1, [srcq]
  por                   m1, m5
  mova                  m5, [srcq+16]
  psubusw               m5, m2
  psubusw               m2, [srcq+16]
  por                   m2, m5
  mova                  m5, [srcq+32]
  psubusw               m5, m3
  psubusw               m3, [srcq+32]
  por                   m3, m5
  mova                  m5, [srcq+48]
  psubusw               m5, m4
  psubusw               m4, [srcq+48]
  por                   m4, m5
  paddw                 m1, m2
  paddw                 m3, m4
  movhlps               m2, m1
  movhlps               m4, m3
  paddw                 m1, m2
  paddw                 m3, m4
  punpcklwd             m1, m6
  punpcklwd             m3, m6
  lea                 refq, [refq+ref_strideq*2]
  paddd                 m0, m1
  lea                 srcq, [srcq+src_strideq*2]
  paddd                 m0, m3
  dec              n_rowsd
  jg .loop

  movhlps               m1, m0
  paddd                 m0, m1
  punpckldq             m0, m6
  movhlps               m1, m0
  paddd                 m0, m1
  movd                 eax, m0
  RET
%endmacro

INIT_XMM sse2
HIGH_SAD32XN 64 ; highbd_sad32x64_sse2
HIGH_SAD32XN 32 ; highbd_sad32x32_sse2
HIGH_SAD32XN 16 ; highbd_sad32x16_sse2
HIGH_SAD32XN 64, 1 ; highbd_sad32x64_avg_sse2
HIGH_SAD32XN 32, 1 ; highbd_sad32x32_avg_sse2
HIGH_SAD32XN 16, 1 ; highbd_sad32x16_avg_sse2
HIGH_SAD32XN 8 ; highbd_sad_32x8_sse2
HIGH_SAD32XN 8, 1 ; highbd_sad_32x8_avg_sse2

; unsigned int aom_highbd_sad16x{8,16,32}_sse2(uint8_t *src, int src_stride,
;                                    uint8_t *ref, int ref_stride);
%macro HIGH_SAD16XN 1-2 0
  HIGH_SAD_FN 16, %1, 5, %2
  mov              n_rowsd, %1/2
  pxor                  m0, m0
  pxor                  m6, m6

.loop:
  movu                  m1, [refq]
  movu                  m2, [refq+16]
  movu                  m3, [refq+ref_strideq*2]
  movu                  m4, [refq+ref_strideq*2+16]
%if %2 == 1
  pavgw                 m1, [second_predq+mmsize*0]
  pavgw                 m2, [second_predq+16]
  pavgw                 m3, [second_predq+mmsize*2]
  pavgw                 m4, [second_predq+mmsize*2+16]
  lea         second_predq, [second_predq+mmsize*4]
%endif
  mova                  m5, [srcq]
  psubusw               m5, m1
  psubusw               m1, [srcq]
  por                   m1, m5
  mova                  m5, [srcq+16]
  psubusw               m5, m2
  psubusw               m2, [srcq+16]
  por                   m2, m5
  mova                  m5, [srcq+src_strideq*2]
  psubusw               m5, m3
  psubusw               m3, [srcq+src_strideq*2]
  por                   m3, m5
  mova                  m5, [srcq+src_strideq*2+16]
  psubusw               m5, m4
  psubusw               m4, [srcq+src_strideq*2+16]
  por                   m4, m5
  paddw                 m1, m2
  paddw                 m3, m4
  movhlps               m2, m1
  movhlps               m4, m3
  paddw                 m1, m2
  paddw                 m3, m4
  punpcklwd             m1, m6
  punpcklwd             m3, m6
  lea                 refq, [refq+ref_strideq*4]
  paddd                 m0, m1
  lea                 srcq, [srcq+src_strideq*4]
  paddd                 m0, m3
  dec              n_rowsd
  jg .loop

  movhlps               m1, m0
  paddd                 m0, m1
  punpckldq             m0, m6
  movhlps               m1, m0
  paddd                 m0, m1
  movd                 eax, m0
  RET
%endmacro

INIT_XMM sse2
HIGH_SAD16XN 32 ; highbd_sad16x32_sse2
HIGH_SAD16XN 16 ; highbd_sad16x16_sse2
HIGH_SAD16XN  8 ; highbd_sad16x8_sse2
HIGH_SAD16XN 32, 1 ; highbd_sad16x32_avg_sse2
HIGH_SAD16XN 16, 1 ; highbd_sad16x16_avg_sse2
HIGH_SAD16XN  8, 1 ; highbd_sad16x8_avg_sse2
HIGH_SAD16XN 4 ; highbd_sad_16x4_sse2
HIGH_SAD16XN 4, 1 ; highbd_sad_16x4_avg_sse2
HIGH_SAD16XN 64 ; highbd_sad_16x64_sse2
HIGH_SAD16XN 64, 1 ; highbd_sad_16x64_avg_sse2

; unsigned int aom_highbd_sad8x{4,8,16}_sse2(uint8_t *src, int src_stride,
;                                    uint8_t *ref, int ref_stride);
%macro HIGH_SAD8XN 1-2 0
  HIGH_SAD_FN 8, %1, 7, %2
  mov              n_rowsd, %1/4
  pxor                  m0, m0
  pxor                  m6, m6

.loop:
  movu                  m1, [refq]
  movu                  m2, [refq+ref_strideq*2]
  movu                  m3, [refq+ref_strideq*4]
  movu                  m4, [refq+ref_stride3q*2]
%if %2 == 1
  pavgw                 m1, [second_predq+mmsize*0]
  pavgw                 m2, [second_predq+mmsize*1]
  pavgw                 m3, [second_predq+mmsize*2]
  pavgw                 m4, [second_predq+mmsize*3]
  lea         second_predq, [second_predq+mmsize*4]
%endif
  mova                  m5, [srcq]
  psubusw               m5, m1
  psubusw               m1, [srcq]
  por                   m1, m5
  mova                  m5, [srcq+src_strideq*2]
  psubusw               m5, m2
  psubusw               m2, [srcq+src_strideq*2]
  por                   m2, m5
  mova                  m5, [srcq+src_strideq*4]
  psubusw               m5, m3
  psubusw               m3, [srcq+src_strideq*4]
  por                   m3, m5
  mova                  m5, [srcq+src_stride3q*2]
  psubusw               m5, m4
  psubusw               m4, [srcq+src_stride3q*2]
  por                   m4, m5
  paddw                 m1, m2
  paddw                 m3, m4
  movhlps               m2, m1
  movhlps               m4, m3
  paddw                 m1, m2
  paddw                 m3, m4
  punpcklwd             m1, m6
  punpcklwd             m3, m6
  lea                 refq, [refq+ref_strideq*8]
  paddd                 m0, m1
  lea                 srcq, [srcq+src_strideq*8]
  paddd                 m0, m3
  dec              n_rowsd
  jg .loop

  movhlps               m1, m0
  paddd                 m0, m1
  punpckldq             m0, m6
  movhlps               m1, m0
  paddd                 m0, m1
  movd                 eax, m0
  RET
%endmacro

INIT_XMM sse2
HIGH_SAD8XN 16 ; highbd_sad8x16_sse2
HIGH_SAD8XN  8 ; highbd_sad8x8_sse2
HIGH_SAD8XN  4 ; highbd_sad8x4_sse2
HIGH_SAD8XN 16, 1 ; highbd_sad8x16_avg_sse2
HIGH_SAD8XN  8, 1 ; highbd_sad8x8_avg_sse2
HIGH_SAD8XN  4, 1 ; highbd_sad8x4_avg_sse2
HIGH_SAD8XN 32 ; highbd_sad_8x32_sse2
HIGH_SAD8XN 32, 1 ; highbd_sad_8x32_avg_sse2

; unsigned int aom_highbd_sad4x{4,8,16}_sse2(uint8_t *src, int src_stride,
;                                    uint8_t *ref, int ref_stride);
%macro HIGH_SAD4XN 1-2 0
  HIGH_SAD_FN 4, %1, 7, %2
  mov              n_rowsd, %1/4
  pxor                  m0, m0
  pxor                  m6, m6

.loop:
  movq                  m1, [refq]
  movq                  m2, [refq+ref_strideq*2]
  movq                  m3, [refq+ref_strideq*4]
  movq                  m4, [refq+ref_stride3q*2]
  punpcklwd             m1, m3
  punpcklwd             m2, m4
%if %2 == 1
  movq                  m3, [second_predq+8*0]
  movq                  m5, [second_predq+8*2]
  punpcklwd             m3, m5
  movq                  m4, [second_predq+8*1]
  movq                  m5, [second_predq+8*3]
  punpcklwd             m4, m5
  lea         second_predq, [second_predq+8*4]
  pavgw                 m1, m3
  pavgw                 m2, m4
%endif
  movq                  m5, [srcq]
  movq                  m3, [srcq+src_strideq*4]
  punpcklwd             m5, m3
  movdqa                m3, m1
  psubusw               m1, m5
  psubusw               m5, m3
  por                   m1, m5
  movq                  m5, [srcq+src_strideq*2]
  movq                  m4, [srcq+src_stride3q*2]
  punpcklwd             m5, m4
  movdqa                m4, m2
  psubusw               m2, m5
  psubusw               m5, m4
  por                   m2, m5
  paddw                 m1, m2
  movdqa                m2, m1
  punpcklwd             m1, m6
  punpckhwd             m2, m6
  lea                 refq, [refq+ref_strideq*8]
  paddd                 m0, m1
  lea                 srcq, [srcq+src_strideq*8]
  paddd                 m0, m2
  dec              n_rowsd
  jg .loop

  movhlps               m1, m0
  paddd                 m0, m1
  punpckldq             m0, m6
  movhlps               m1, m0
  paddd                 m0, m1
  movd                 eax, m0
  RET
%endmacro

INIT_XMM sse2
HIGH_SAD4XN 16 ; highbd_sad4x16_sse2
HIGH_SAD4XN  8 ; highbd_sad4x8_sse2
HIGH_SAD4XN  4 ; highbd_sad4x4_sse2
HIGH_SAD4XN 16, 1 ; highbd_sad4x16_avg_sse2
HIGH_SAD4XN  8, 1 ; highbd_sad4x8_avg_sse2
HIGH_SAD4XN  4, 1 ; highbd_sad4x4_avg_sse2
