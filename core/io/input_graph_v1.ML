


(* XMl Parsers for BANG_GRAPH, RG_VERTEX, and RG_EDGE *)
(* FIXME: structure used is a bit squanky and ineffeccient. *)
functor InputGraphXML_v1(
  structure Graph : BANG_GRAPH
        and InputVertexData : INPUT_XML 
        and InputEdgeData : INPUT_XML 
  sharing type InputVertexData.data = Graph.Vertex.data
  sharing type InputEdgeData.data = Graph.Edge.data
)  : INPUT_XML
= struct
  open XML_Parse_Utils; 

  structure G = Graph;
  structure V = Graph.OVertex;
  structure E = Graph.Edge;
  structure B = Graph.BBox;
  
  type T = XML.tree;  (* XML.tree *)
  type data = Graph.T;

  fun data_to_string _ = "[Graph]";

(* 
  val input_source = force_get_text_from "source"
  val input_target = force_get_text_from "target"
*)
      
  fun input_edge_rel xml = 
      let 
        val _ = assert_tag "edge" xml
        val children = get_children xml 
        val name = E.mk (apply_to_unique_elem get_unique_child_text "name" children)
          handle bad_input_exp (s,p) => raise bad_input_exp (s,"edge/"^p)
        val source = V.mk (apply_to_unique_elem get_unique_child_text "source" children)
          handle bad_input_exp (s,p) => raise bad_input_exp (s,"edge("^(E.dest name)^")/"^p)
        val target = V.mk (apply_to_unique_elem get_unique_child_text "target" children)
          handle bad_input_exp (s,p) => raise bad_input_exp (s,"edge("^(E.dest name)^")/"^p)
        val edata = InputEdgeData.input xml
          handle bad_input_exp (s,p) => raise bad_input_exp (s,"edge("^(E.dest name)^")/"^p)
      in (name,edata,source,target) end;
  
  fun input_bbox xml =
      let 
        val _ = assert_tag "bangbox" xml
        val children = get_children xml 
        val name = B.mk (apply_to_unique_elem get_unique_child_text "name" children)
          handle bad_input_exp (s,p) => raise bad_input_exp (s,"bangbox/"^p)
        val bangverts = List.map (V.mk o get_unique_child_text) 
                                 (filter_elems "boxedvertex" children)
          handle bad_input_exp (s,p) => raise bad_input_exp (s,"bangbox("^(B.dest name)^")/"^p)
      in (name,bangverts) end;
  
  (* uncurry some graph methods *)
  fun add_v (vname,vdata) g = 
      snd (G.add_named_vertex vname vdata g)
  
  (* FIXME: load up direction information *)
  fun add_e (ename,edata,src,tgt) g = 
      snd (G.add_named_edge ename (G.UnDirected,edata) src tgt g)
  
  fun add_bb (bname,bvlist) g = 
      let val (realname, g') = G.new_box bname g
          val vset  = V.NSet.of_list bvlist
      in
        G.move_to_box realname vset g'
      end
  
  fun input_vertex xml = 
      let val () = assert_tag "vertex" xml
          val children = get_children xml
          val name = V.mk (apply_to_unique_elem get_unique_child_text "name" children)
            handle bad_input_exp (s,p) => raise bad_input_exp (s,"vertex/"^p)
      in
        (name, InputVertexData.input xml)
          handle bad_input_exp (s,p) => raise bad_input_exp (s,"vertex("^(V.dest name)^")/"^p)
      end;

  fun input_graph xml =
      (let 
         val () = assert_tag "graph" xml
         val children = get_children xml
         val vertices = List.map input_vertex (filter_elems "vertex" children)
         val edges = List.map input_edge_rel (filter_elems "edge" children)
         val bboxes = List.map input_bbox (filter_elems "bangbox" children)
       in
         G.empty 
           |> fold add_v vertices 
           |> fold add_e edges
           |> fold add_bb bboxes 
       end)
      handle bad_input_exp (s,p) => raise bad_input_exp (s,"graph/"^p);
  
  val input = input_graph;
			   
end (* structure InputXML *)


(* ------------------------------------------------------- *)
functor InputRGVertexDataXML_v1(
  V : OVERTEX where type IData.data = RG_VertexData.data
) : INPUT_XML
= struct
  open XML_Parse_Utils; 
  
  type T = XML.tree;
  type data = V.data;
  
  fun data_to_string _ = "[Vertex data]";

  fun input_rational xml = 
      let val children = get_children xml;
          val num = get_unique_child (get_unique_elem "num" children)
          val denom = get_unique_child (get_unique_elem "denom" children)
      in (InputIntXML.input num, InputIntXML.input denom) end;
  
  fun input_constant xml =
      (let val () = assert_tag "constant" xml
       in input_rational xml end)
      handle bad_input_exp (s,p) => raise bad_input_exp (s,"constant/"^p);
  
  fun input_coeff xml = 
      (let val () = assert_tag "coefficient" xml
       in input_rational xml end)
      handle bad_input_exp (s,p) => raise bad_input_exp (s,"coefficient/"^p);
  
  fun input_variable xml = 
      (let val _ = assert_tag "variable" xml
           val children = get_children xml
           val name = get_unique_child_text (get_unique_elem "name" children)
           val coeff = get_unique_elem "coefficient" children
       in (name, input_coeff coeff) end)
      handle bad_input_exp (s,p) => raise bad_input_exp (s,"variable/"^p);
  
  fun input_angleexpr xml  =
      (let val () = assert_tag "angleexpr" xml
           val children = get_children xml 
           val constant = case (lookup_unique_elem "constant" children) of
                            (NONE) => LinratExpr.Coeff.zero
                          | (SOME const) => input_constant const
           val vars = List.map input_variable (filter_elems "variable" children)
       in LinratExpr.mk constant vars end)
      handle bad_input_exp (s,p) => raise bad_input_exp (s,"angleexpr/"^p);
    
  fun input_vertex_idata xml =
      let val () = assert_tag "vertex" xml
          val children = get_children xml
          val col = (String.map Char.toLower o get_unique_child_text 
                     o get_unique_elem "colour") children
      in 
        if (col = "h") then RG_VertexData.Hnd
        else
          let 
            val angle = 
                case lookup_unique_elem "angleexpr" children of NONE => LinratExpr.zero
                   | SOME a => input_angleexpr a
          in
            if (col = "green") then RG_VertexData.Znd angle
            else if (col = "red") then RG_VertexData.Xnd angle
            else raise bad_input_exp ("Unknown colour : "^col^".","")
          end
      end;

  fun input xml = 
      let 
        val () = assert_tag "vertex" xml
        val children = get_children xml
      in
        case lookup_unique_elem "boundary" children of 
          NONE => (V.IVert (input_vertex_idata xml))
        | SOME boundary_xml => 
          if InputBoolXML.input (get_unique_child boundary_xml) then (V.EVert)
          else (V.IVert (input_vertex_idata xml)) 
      end;

end; (* functor RGGraphInputXML*)

functor InputNoEdgeDataXML_v1(E : EDGE) :  INPUT_XML
= struct
  open XML_Parse_Utils;
  type T = XML.tree;
  type data = E.data;
  fun data_to_string _ = "[Edge data]";
  val input = K E.default_data;
end;

(* vim:et:sts=2:sw=2
*)
