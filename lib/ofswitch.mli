(*
 * Copyright (c) 2011 Richard Mortier <mort@cantab.net>
 * Copyright (c) 2011 Charalampos Rotsos <cr409@cl.cam.ac.uk>
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


type t
val add_port : Net.Manager.t -> ?use_mac:bool -> t -> string -> unit Lwt.t
val del_port : Net.Manager.t -> t -> string -> unit Lwt.t
val add_port_local : Net.Manager.t -> t -> Net.Manager.id -> unit Lwt.t
val add_flow : t -> Ofpacket.Flow_mod.t -> unit Lwt.t
val del_flow : t -> Ofpacket.Match.t -> unit Lwt.t
val get_flow_stats : t -> Ofpacket.Match.t -> Ofpacket.Flow.stats list 
val create_switch : unit -> t
val listen : t -> Net.Manager.t -> Net.Nettypes.ipv4_src -> 
  unit Lwt.t 
val connect : t -> Net.Manager.t -> Net.Nettypes.ipv4_dst -> 
  unit Lwt.t
(*
val lwt_connect : t -> ?standalone:bool -> Net.Manager.t -> Net.Nettypes.ipv4_dst -> 
  unit Lwt.t
 *)
val local_connect : t -> Net.Manager.t -> 
  Ofpacket.t Lwt_stream.t -> (Ofpacket.t option -> unit ) -> 
     unit Lwt.t
