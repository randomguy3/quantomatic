(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *) 
(*  isomorphism between bang graphs  *)
(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- *) 
signature BANG_GRAPH_ISO_SHARING
= sig
  include GRAPH_ISO_SHARING
  structure BBoxInjEndo : NAME_INJENDO_SHARING
end;


signature BANG_GRAPH_ISO
= sig
  include GRAPH_ISO
  structure BBoxInjEndo : NAME_INJENDO;

  structure SharingWithBBox : BANG_GRAPH_ISO_SHARING
  sharing Sharing = SharingWithBBox;
  sharing BBoxInjEndo.Sharing = SharingWithBBox.BBoxInjEndo;

  val get_bmap : T -> BBoxInjEndo.T
end;


functor BangGraphIso(Graph : BANG_GRAPH) 
: BANG_GRAPH_ISO
= struct
  
  structure Vertex = Graph.Vertex;
  structure Edge = Graph.Edge;
  structure Param = Graph.Param;
  structure BBoxInjEndo = Graph.BBoxInjEndo;
  
  type graph = Graph.T;
  type T = (Vertex.InjEndo.T * Edge.InjEndo.T * BBoxInjEndo.T * Param.subst);  

  structure Sharing =
  struct 
    structure Param = Param.Sharing
    type T = T
    type graph = graph;
  end;
  structure SharingWithBBox = 
  struct
    open Sharing; 
    structure BBoxInjEndo = BBoxInjEndo.Sharing
  end;

  fun get_vmap (v,_,_,_) = v;
  fun get_emap (_,e,_,_) = e;
  fun get_bmap (_,_,b,_) = b;
  fun get_subst (_,_,_,u) = u;
  
  fun match_edge_both_ways e1 e2 (u,u') = 
      (u |> Param.match_edge e1 e2, u'|> Param.match_edge e2 e1);
  
  fun match_vertex_both_ways v1 v2 (u,u') = 
      (u |> Param.match_vertex v1 v2, u'|> Param.match_vertex v2 v1);
      
  exception box_mismatch_exp of unit;
  fun match_boxes g h vng vnh b =
      (case (Graph.lookup_box_of g vng,Graph.lookup_box_of h vnh) of
           (NONE,NONE)       =>  b
         | (SOME bg,SOME bh) => ((b |> BBoxInjEndo.add bg bh)
                                handle BBoxInjEndo.add_exp _ 
                                    => raise box_mismatch_exp())
         | _                 => raise box_mismatch_exp ());
      
    
  (* v = vertex iso, 
     e = edge iso, 
     b = bbox iso,
     u = matching so far (G.Param.subst = a substitution), 
     t = agenda, 
     g and h = graphs, 
  *)
  fun get_isomorphisms_match_next_edge v e b u t g h gs hs otherend = let
      val n1 = Option.valOf
              (Edge.NSet.get_local_bot gs)
      val ((dir1,d1),_) = Graph.get_edge g n1
    in 
      Seq.maps get_isomorphisms_match_next
      (Seq.map_filter
        (fn n2 => 
            let val ((dir2,d2),_) = Graph.get_edge h n2 in
              if dir1 <> dir2 (* andalso Edge.data_eq(d1,d2) *) 
              then NONE 
              else SOME
                (v |> Vertex.InjEndo.add (otherend n1 g) (otherend n2 h),
                 e |> Edge.InjEndo.add n1 n2,
                 b,
                 u |> match_edge_both_ways d1 d2,
                 Seq.append t  (* push match of the target vertex of
                                  this edge onto the match queue *)
                   (Seq.single (otherend n1 g,
                                otherend n2 h)),
                 g |> Graph.delete_edge n1,
                 h |> Graph.delete_edge n2)
                 handle Vertex.InjEndo.add_exp _ => NONE
                      | Param.match_exp _         => NONE
             end)
          (Edge.NSet.seq_of hs))
    end
  and get_isomorphisms_match_next (v,e,b,u,t,g,h) = 
    (case Seq.pull t of
      (* Nothing to match; start matching new connectivity component *)
      NONE                => let
         val gbot = the (Vertex.NSet.get_local_bot (Graph.get_vnames g))
         val hmin = Vertex.NSet.get_min (Graph.get_vnames h)
         fun maketuple n = (v,e,b,u,Seq.single (gbot,n),g,h);
      in Seq.map maketuple (Vertex.NSet.seq_of (Graph.get_vnames h)) end 
      (* Something to match; return lazy list of all possible next steps *)
    | SOME ((vng,vnh),t') => let
         (* point undirected edges towards us *)
         fun attract e gr = let
             val ((dir,_),_) = Graph.get_edge gr e
           in if dir=Graph.UnDirected
              then Graph.swap_edge_dir e gr
              else gr end
         val (_,(_,gout)) = Graph.get_vertex g vng
         val (_,(_,hout)) = Graph.get_vertex h vnh
         val g = g |> Edge.NSet.fold attract gout
         val h = h |> Edge.NSet.fold attract hout
         (* some other helper stuff *)
         val (gd,(gin,gout)) = Graph.get_vertex g vng
         val (hd,(hin,hout)) = Graph.get_vertex h vnh
         fun esrc n x = let val (_,(f,t)) = Graph.get_edge x n
                   in f end;
         fun esnk n x = let val (_,(f,t)) = Graph.get_edge x n
                   in t end;
      in if true (*Vertex.data_eq (gd,hd)*)
         then case (Edge.NSet.is_empty gin,
                    Edge.NSet.is_empty hin,
                    Edge.NSet.is_empty gout,
                    Edge.NSet.is_empty hout) of
            (* no (more) edges; match up *)
            (true,true,true,true) =>
              Seq.single (v |> Vertex.InjEndo.add vng vnh,
                          e,
                          b |> match_boxes g h vng vnh,
                          u |> match_vertex_both_ways gd hd,
                          t',
                          g |> Graph.delete_vertex vng,
                          h |> Graph.delete_vertex vnh)
            (* some outgoing edges remaining *)
          | (_,_,false,false) =>
            get_isomorphisms_match_next_edge v e b u t g h gout hout esnk
            (* some incoming edges remaining *)
          | (false,false,_,_) => 
            get_isomorphisms_match_next_edge v e b u t g h gin hin esrc
            (* edge mismatch *)
          | _ => Seq.empty
         else Seq.empty (* Mismatching vertex data *)
       end handle Graph.no_such_vname_exp(_,_,_)
                                         (* consequence of multiple edges. 
                                            Vertex has already been successfully
                                            matched; skip. *)
               => get_isomorphisms_match_next (v,e,b,u,t',g,h)
    ) handle Vertex.InjEndo.add_exp _ => Seq.empty
           | Param.match_exp _         => Seq.empty
           | box_mismatch_exp _       => Seq.empty
  
  (* v,e are working copies of the isomorphism to be constructed;
     t is the queue of vertex pairs in the source and target graph to be
     matched *)
  fun get_isomorphisms_sub (v,e,b,u,t,g,h) = case (Graph.is_empty g,
                                                   Graph.is_empty h) of
      (* both graphs are empty; done *)
      (true,true) => Seq.single (v,e,b,fst u)
      (* neither graph is empty; get possible next match steps and
         proceed matching *)
    | (false,false) => Seq.maps get_isomorphisms_sub
                                        (get_isomorphisms_match_next (v,e,b,u,t,g,h))
      (* one graph is empty and the other is not; no iso *)
    | _ => Seq.empty 
  ;
    
  (* in:  graphs g, h *)
  (* out: lazy list of (Vertex isomorphism*Edge isomorphism) containing all
          isomorphisms between g and h *)
  fun get g h  
    = get_isomorphisms_sub (Vertex.InjEndo.empty,Edge.InjEndo.empty,BBoxInjEndo.empty,
                            (Param.empty_subst,Param.empty_subst),Seq.empty,g,h);
  
  (* in:  graphs g, h *)
  (* out: true if g~=h, false otherwise *)
  val test : graph -> graph -> bool 
    = is_some o Seq.pull oo get
  
    
end;