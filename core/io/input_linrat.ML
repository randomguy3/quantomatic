structure InputLinratXML : INPUT_XML where type data = LinratExpr.T
= struct

  open XML_Parse_Utils; 

  structure VName = LinratExpr.VName;
  
  type T = XML.tree;  (* XML.tree *)
  type data = LinratExpr.T;

  val data_to_string = Pretty.string_of o LinratExpr.pretty;
  
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
  
  fun input xml  =
      (let val () = assert_tag "angleexpr" xml
           val children = get_children xml 
           val constant = case (lookup_unique_elem "constant" children) of
                            (NONE) => LinratExpr.Coeff.zero
                          | (SOME const) => input_constant const
           val vars = List.map input_variable (filter_elems "variable" children)
       in LinratExpr.mk constant vars end)
      handle bad_input_exp (s,p) => raise bad_input_exp (s,"angleexpr/"^p);

end;
