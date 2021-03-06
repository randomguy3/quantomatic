(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *) 
(*   Rules for rewriting graphs *)
(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- *)
(* 
    We store the lhs, rhs, lhs-automorphisms, and the computed rule-automorphisms. 
*)

signature RULE_SHARING =
sig
  structure Graph : BANG_GRAPH_SHARING
  structure GraphIso : BANG_GRAPH_ISO_SHARING 
  sharing type GraphIso.graph = Graph.T
  sharing GraphIso.Param = Graph.Param 
  sharing GraphIso.BBoxInjEndo = Graph.BBoxInjEndo
  type T
end

signature BASIC_RULE 
= sig
  structure Graph : BANG_GRAPH
  structure GraphIso : BANG_GRAPH_ISO
  
  type T (* rule *)

  structure Sharing : RULE_SHARING
  sharing Sharing.Graph = Graph.SharingBangGraph
  sharing Sharing.GraphIso = GraphIso.SharingWithBBox
  sharing type Sharing.T = T  

  exception bad_rule_exp of string * Graph.T * Graph.T;
  val mk : (Graph.T * Graph.T) -> T;
    
  (* NOTE: FIXME: these don't touch the automorphism data; they should not be used without reconstructing the automoprhism info. *)
  val try_rename1_ename : Graph.Edge.name -> Graph.Edge.name -> T -> T option
  val try_rename1_vname : Graph.Vertex.name -> Graph.Vertex.name 
      -> T -> T option
  val try_rename1_bname : Graph.BBox.name -> Graph.BBox.name -> T -> T option
  
  structure VertexCRnm : COMPOUND_RENAMING 
  where type obj = T and type renaming = Graph.Vertex.Rnm.T
  structure EdgeCRnm : COMPOUND_RENAMING 
  where type obj = T and type renaming = Graph.Edge.Rnm.T
  structure BBoxCRnm : COMPOUND_RENAMING 
  where type obj = T and type renaming = Graph.BBox.Rnm.T

  val rename : (Graph.Vertex.Rnm.T * Graph.Edge.Rnm.T * Graph.BBox.Rnm.T) -> T 
            -> (Graph.Vertex.Rnm.T * Graph.Edge.Rnm.T * Graph.BBox.Rnm.T) * T

  val get_lhs : T -> Graph.T
  val get_rhs : T -> Graph.T
  
  val get_vnames : T -> Graph.Vertex.NSet.T
  val get_enames : T -> Graph.Edge.NSet.T
  val get_bnames : T -> Graph.BBox.NSet.T

  (* swaps lhs and rhs *)
  val symmetric : T -> T
  
  (* rule is a trivial identity : lhs matches rhs *)
  val is_trivial : T -> bool
  

  (* extra cached meta-data *)
  datatype 'a tree = Tree of ('a * 'a tree list);
  datatype constr   =   Constrained
                      | Arbitrary
  datatype 'a otype =   Initial of constr
                      | Rooted of constr * 'a
                      | Boundary of 'a;
  (* gets cached symmetry match-search order *)  
  val get_order : T -> (Graph.Vertex.name otype * Graph.Vertex.name tree) list

  (* for pretty printing *)
  val pretty : T -> Pretty.T
  val print : T -> unit
end;

signature RULE 
= sig
  include BASIC_RULE
  (* TODO add stuff specific to automorphisms of rules *)
end;


(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *) 
functor Rule(Graph : BANG_GRAPH)
= struct

structure Graph = Graph;
structure Vertex = Graph.Vertex;
structure Edge = Graph.Edge;
structure GraphIso = BangGraphIso(Graph);

(* Names of rules *)
structure Name 
= struct
  open SStrName;
  val default_name = SStrName.mk "new-rule-1"
end


datatype 'a tree = Tree of ('a * 'a tree list);
type order = (Vertex.name option * Vertex.name tree) list;
datatype constr   =   Constrained
                    | Arbitrary
datatype 'a otype =   Initial of constr
                    | Rooted of constr * 'a
                    | Boundary of 'a;

fun keep_if_fixed n a = if Vertex.name_eq ((  Vertex.InjEndo.domf
                                            o GraphIso.get_vmap) a n, n)
                        then [a]
                        else [];
fun fix v auts = maps (keep_if_fixed v) auts;

fun take_orbit auts vset =
    let val v   = (the o Vertex.NSet.get_local_bot) vset
        val orb = fold (fn x => Vertex.NSet.add ((  Vertex.InjEndo.domf
                                                  o GraphIso.get_vmap) x v))
                       auts Vertex.NSet.empty
    in  (v, orb, Vertex.NSet.subtract vset orb) end;

fun gen_order_sub g auts vset =
    if Vertex.NSet.is_empty vset then (auts,[])
    else let val (v,orb,rest) = take_orbit auts vset
             val auts' = fix v auts
             val (auts'',subtr) = gen_order_sub g auts'
                                                (Vertex.NSet.delete v orb)
             val (auts''',tail) = gen_order_sub g auts''
                                                (Vertex.NSet.subtract vset orb)
         in  (auts''', Tree (v, subtr)::tail) end;
                           
fun gen_order g auts done bound =
    let val aset = Graph.incident_vertices g done
        val (root,vset)=if Vertex.NSet.is_empty aset
                      then (NONE,Graph.get_vnames g
                                 |> Vertex.NSet.remove_set done
                                 |> Vertex.NSet.remove_set (Graph.get_boundary g))
                      else (SOME((the (* must be nonempty by adjacency *)
                                 o Vertex.NSet.get_local_bot
                                oo Vertex.NSet.intersect) done
                                     ((Graph.adj_vnames g
                                     o the
                                     o Vertex.NSet.get_local_bot) aset))
                             ,aset)
    in if Vertex.NSet.is_empty vset then []
    else case root of NONE => let val vsetb = Vertex.NSet.intersect vset bound
                                  val (vset,typ) = if Vertex.NSet.is_empty vsetb
                                                 then (vset,Initial Arbitrary)
                                                 else (vsetb,Initial Constrained)
                                  val (v,orb,_) = take_orbit auts vset
                                  val auts' = fix v auts
                                  val bound' = Vertex.NSet.union_merge bound orb
                              in   (typ,Tree(v,[]))
                                 ::gen_order g auts'
                                             (Vertex.NSet.add v done) bound' 
                              end
                  | SOME x => let val (v,orb,rest) = take_orbit auts vset
                                  val auts' = fix v auts
                                  val (auts'',subtr)
                                      = gen_order_sub g auts'
                                                      (Vertex.NSet.delete v orb) 
                              in (  if      Vertex.NSet.contains bound v
                                  then Rooted (Constrained,x)
                                  else   if Graph.is_boundary g v
                                       then Boundary x
                                       else Rooted (Arbitrary,x),
                                  Tree(v, subtr))::gen_order g auts''
                                         (Vertex.NSet.union_merge done orb)
                                         bound
                              end
    end;

(* selfapps only contains a remapping of boundary vertices and substitution
   for data. *)
datatype T = Rule of { lhs : Graph.T,
                       rhs : Graph.T,
                       lhs_aut : GraphIso.T list,
                       selfapps : (Vertex.InjEndo.T*GraphIso.Param.subst) list,
                       order : (Vertex.name otype * Vertex.name tree) list
                     };

exception bad_rule_exp of string * Graph.T * Graph.T;
fun mk (lhs,rhs) = 
    let val lhsbndry : Vertex.NSet.T = Graph.get_boundary lhs 
    in
    (* check that rule is well-formed! *)
    if Vertex.NSet.eq lhsbndry (Graph.get_boundary rhs) then 
      let (* rename rhs; sharing bvertex names with lhs, 
             all else must be distinct, but do minimal amount of renaming *)
        val ignorevnames = (* ignore boundary and also fresh rhs vnames *)
            Vertex.NSet.union_merge 
              lhsbndry
              (Vertex.NSet.subtract (Graph.get_vnames rhs)
                                    (Graph.get_vnames lhs)); 
        (* ignore enames that are already fresh w.r.t. lhs *)
        val ignoreenames = Edge.NSet.subtract (Graph.get_enames rhs)
                            (Graph.get_enames lhs);
        val vrn = Vertex.mk_renaming ignorevnames 
                    (Vertex.NSet.union_merge ignorevnames 
                      (Graph.get_vnames lhs))
                    Vertex.NTab.empty
        val ern = Edge.mk_renaming ignoreenames 
                    (Edge.NSet.union_merge ignoreenames (Graph.get_enames lhs))
                    Edge.NTab.empty
        val (rn, rhs') = Graph.rename (vrn,ern) rhs
        val lhsauts = (Seq.list_of oo GraphIso.get) lhs lhs
        val rhsauts = (Seq.list_of oo GraphIso.get) rhs rhs'
        val lhsba = map (fn x => ((  Vertex.InjEndo.restrict_dom_to lhsbndry
                                   o GraphIso.get_vmap) x,GraphIso.get_subst x))
                        lhsauts
        val rhsba = map (fn x => ((  Vertex.InjEndo.restrict_dom_to lhsbndry
                                   o GraphIso.get_vmap) x,GraphIso.get_subst x))
                        rhsauts
        (* fetches one representative from the orbit of each LHS aut|boundary
           under Aut(rhs), using fact that l1~=l2 <-> there exists an r such
           that r.l2 = l1 *)
        fun filterorbits (x::xs) os =
            let val orbit = map ((Vertex.InjEndo.compose (fst x)) o fst) rhsba 
                fun eq a b = ((Vertex.NTab.fold 
                                      (fn (d,c) => Vertex.InjEndo.add d c)
                                      (Vertex.InjEndo.get_domtab a) b; true)
                             handle Vertex.InjEndo.add_exp _ => false)
                val xs' = filter_out
                            (fn a => exists (eq (fst a)) orbit)
                            xs
            in filterorbits xs' (x::os) end
          | filterorbits [] os = os
      in Rule { lhs = lhs, rhs = rhs',
                lhs_aut = lhsauts,
                selfapps = filterorbits lhsba [],
                order = gen_order lhs lhsauts
                                  Vertex.NSet.empty Vertex.NSet.empty } end
    else
      raise bad_rule_exp ("mk: Left and right hand side boundaries are different", lhs, rhs)
    end;

(* 
fun rename_interior_vs xvs (avoidvs, avoides, avoidbs) g = 
     let (* rename rhs; shared bvertex names, all else is distinct. *)
        val vrn = Vertex.mk_renaming xvs avoidvs Vertex.NTab.empty
  in Graph.rename (vrn,Edge.Rnm.empty) g  end;
*)

(* match anything = no set matching *)
(* val any_match = Match.empty; *)

fun get_lhs (Rule rep) = #lhs rep;
fun get_rhs (Rule rep) = #rhs rep;
fun get_order (Rule rep) = #order rep;

fun update_lhs f (Rule rep) = 
    Rule { lhs = f (#lhs rep), rhs = #rhs rep, lhs_aut = #lhs_aut rep, selfapps = #selfapps rep, order = #order rep };
fun update_rhs f (Rule rep) = 
    Rule { lhs = #lhs rep, rhs = f (#rhs rep), lhs_aut = #lhs_aut rep, selfapps = #selfapps rep, order = #order rep };

val set_lhs = update_lhs o K;
val set_rhs = update_rhs o K;

(* THINK: cache this info? *)
(* 
fun get_rhs_newnodes r = 
    let val (lhsns,rhsns) = Graph.get_vnames (get_rhs r)
    in Vertex.NSet.subtract rhsns lhsns end;
fun get_lhs_delnodes r =
    let val (lhsns,rhsns) = Graph.get_vnames (get_lhs r)
    in Vertex.NSet.subtract lhsns rhsns  end;
fun get_rhs_newedges r =
    let val (lhsns,rhsns) = Graph.get_enames (get_rhs r)
    in Edge.NSet.subtract rhsns lhsns end;
fun get_lhs_deledges r =
    let val (lhsns,rhsns) = Graph.get_enames (get_lhs r)
    in Edge.NSet.subtract lhsns rhsns  end;
*)

(* swap lhs and rhs of a rule *)
fun symmetric r = mk (get_lhs r, get_rhs r);

(* a rule is trivially true if the left and right hand sides match.
   Proof is by observing that bounary nodes can only be matched by
   boundary nodes and the types of the lhs and rhs must be equal to be
   a rule. *)
fun is_trivial rule = raise ERROR "not implemented"; (* FIXME *)
(* 
    let val init_renaming = 
        val rhs' = Graph.rename_apart
    in
    (case Seq.pull (MatchSearch.match (get_lhs rule) (get_rhs rule) 
                                     MatchSearch.Vertex.NTab.empty)
      of NONE => false
       | _ => true);
*)

(*  *)
(* TODO: add renaming for extra stuff (not lhs and rhs) *)
fun get_vnames rule = 
    Graph.Vertex.NSet.union_merge 
      (Graph.get_vnames (get_lhs rule))
      (Graph.get_vnames (get_rhs rule));
fun get_enames rule = 
    Graph.Edge.NSet.union_merge 
      (Graph.get_enames (get_lhs rule))
      (Graph.get_enames (get_rhs rule));
fun get_bnames rule = 
    Graph.BBox.NSet.union_merge 
      (Graph.get_bbnames (get_lhs rule))
      (Graph.get_bbnames (get_rhs rule));

exception tryify_failed of unit
      
fun tryify ff f x = 
    (SOME (ff (fn x => case f x of NONE => raise tryify_failed () 
                                 | SOME y => y)
              x))
    handle tryify_failed () => NONE;

fun untryify f x =  
    (case f x of NONE => raise tryify_failed ()
     | SOME y => y);
    
(* *)
fun try_rename1_vname n1 n2 rule =
    (SOME 
      (rule |> (update_lhs (untryify (Graph.try_rename1_vname n1 n2)))
            |> (update_rhs (untryify (Graph.try_rename1_vname n1 n2)))))
    handle tryify_failed () => NONE;
fun try_rename1_ename n1 n2 rule =     
    (SOME 
      (rule |> (update_lhs (untryify (Graph.try_rename1_ename n1 n2)))
            |> (update_rhs (untryify (Graph.try_rename1_ename n1 n2)))))
    handle tryify_failed () => NONE;
fun try_rename1_bname n1 n2 rule = 
    (SOME 
      (rule |> (update_lhs (untryify (Graph.try_rename1_bname n1 n2)))
            |> (update_rhs (untryify (Graph.try_rename1_bname n1 n2)))))
    handle tryify_failed () => NONE;
    
(* *)
structure VertexCRnm = CompoundRenamingFun(
  struct 
    structure Nm = Graph.Vertex;
    type obj = T
    val try_rename1 = try_rename1_vname;
    val get_nameset = get_vnames
  end);
structure EdgeCRnm = CompoundRenamingFun(
  struct 
    structure Nm = Graph.Edge;
    type obj = T
    val try_rename1 = try_rename1_ename;
    val get_nameset = get_enames
  end);
structure BBoxCRnm = CompoundRenamingFun(
  struct 
    structure Nm = Graph.BBox;
    type obj = T
    val try_rename1 = try_rename1_bname;
    val get_nameset = get_bnames
  end);

(* rename *)
fun rename (vrn,ern,brn) rule = 
    let 
      val (vrn,rule) = VertexCRnm.rename vrn rule
      val (ern,rule) = EdgeCRnm.rename ern rule
      val (brn,rule) = BBoxCRnm.rename brn rule
    in
      (* TODO: rename automorphism info; avoid re-creation. *)
      ((vrn,ern,brn), mk (get_lhs rule,get_rhs rule))
    end;


fun pretty (Rule rep) = 
    Pretty.chunks 
    [Pretty.block [Pretty.str "Rule: "],
     Pretty.block [Pretty.str "LHS: ", Graph.pretty (#lhs rep)],
     Pretty.block [Pretty.str "RHS: ", Graph.pretty (#rhs rep)]];

val print = Pretty.writeln o pretty;


structure Sharing = struct
  structure Graph = Graph.SharingBangGraph;
  structure GraphIso = GraphIso.SharingWithBBox;
  type T = T;
end;

end;

(* -------------------------------------------------------- *)
structure RuleName : SSTR_NAMES = 
  struct open SStrName; val default_name = mk "new-rule-1"; end;
