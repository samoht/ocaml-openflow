(*
 * Copyright (c) 2011 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Nettypes

module TCPv4 : CHANNEL with
      type src =  Nettypes.ipv4_src
  and type dst =  Nettypes.ipv4_dst
  and type mgr = Manager.t

type t

val read_char: t -> char Lwt.t
val read_some: ?len:int -> t -> Cstruct.buf Lwt.t
val read_until: t -> char -> (bool * Cstruct.buf) Lwt.t
val read_stream: ?len:int -> t -> Cstruct.buf Lwt_stream.t
val read_line: t -> Cstruct.buf list Lwt.t

val write_char : t -> char -> unit  
val write_string : t -> string -> int -> int -> unit 
val write_buffer : t -> Cstruct.buf -> unit 
val write_line : t -> string -> unit

val flush : t -> unit Lwt.t
val close : t -> unit Lwt.t

val connect :
  Manager.t -> [> 
   | `TCPv4 of Nettypes.ipv4_src option * Nettypes.ipv4_dst * (t -> unit Lwt.t)
  ] -> unit Lwt.t

val listen :
  Manager.t -> [> 
   | `TCPv4 of Nettypes.ipv4_src * (Nettypes.ipv4_dst -> t -> unit Lwt.t)
  ] -> unit Lwt.t