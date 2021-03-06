(* test IO construction *)
structure Test_IO_Interface_v1 = struct
  structure Input = struct
    structure InputVertexData = InputRGVertexDataXML_v1(Test_Graph.OVertex)
    structure InputEdgeData = InputNoEdgeDataXML_v1(Test_Graph.Edge)

    structure Graph = InputGraphXML_v1(
      structure Graph = Test_Ruleset.Rule.Graph
      structure InputVertexData = InputVertexData
      structure InputEdgeData = InputEdgeData);

    structure Rule = InputRuleXML(
        structure Rule = Test_Ruleset.Rule
        structure InputGraph = Graph);

    structure Ruleset = InputRulesetXML(
      structure Ruleset = Test_Ruleset
      structure InputRule = Rule
      structure InputRuleName = InputRuleNameXML
      structure InputTagName = InputTagNameXML);
  end; (* input *)
end; (* DB_Test_IO_Interface_v1 *)

structure DB_Test_IO_Interface_v2 = IO_Interface(
  structure Ruleset = Test_Ruleset
  structure InputVertexData = InputTypedData(Test_OVertexData_ParamIO);
  structure OutputVertexData = OutputTypedData(Test_OVertexData_ParamIO);
  structure InputEdgeData = InputTypedData(NoEdgeData_ParamIO);
  structure OutputEdgeData = OutputTypedData(NoEdgeData_ParamIO);
);
structure Test_IO_Interface_v2 : IO_INTERFACE = DB_Test_IO_Interface_v2;

