(* Testing Linear Rational Expressions and matching of them. *)
local 
    structure E = DB_LinratExpr; (* expressions *)
    structure V = E.VName; (* Variable names *)
    structure R = E.Coeff; (* rational numbers *)
    
    val zero = E.zero;
    val pi = E.pi;
    
    val a_v = "a";
    val b_v = "b";
    val c_v = "c";
    
    val a = E.mk_var a_v;
    val b = E.mk_var b_v;
    val c = E.mk_var c_v;
    
    val u = R.mk ~1 1
    val w = R.mk 1 6;
    val x = R.mk ~2 3;
    val y = R.mk 7 8;
    val z = R.mk 0 1;
    
    fun op +(x,y) = E.add_expr x y;
    fun op -(x,y) = E.subtr_expr x y;
    fun op *(k,x) = E.scale_expr k x;
    
    val tab1a = V.NTab.update (a_v, pi) V.NTab.empty;
    val tab1b = V.NTab.update (b_v, x*pi) V.NTab.empty;
    val tab1c = V.NTab.update (c_v, zero) V.NTab.empty;
    val tab1ab = V.NTab.update (b_v, pi) tab1a;
    val tab1bc = V.NTab.update (c_v, x*pi) tab1b;
    val tab1ca = V.NTab.update (a_v, zero) tab1c;
    
    val tab2a = V.NTab.update (a_v, pi+x*c) V.NTab.empty;
    val tab2b = V.NTab.update (b_v, x*pi+u*a) V.NTab.empty;
    val tab2c = V.NTab.update (c_v, a) V.NTab.empty;
    val tab2ab = V.NTab.update (b_v, pi+c) tab2a;
    val tab2bc = V.NTab.update (c_v, x*pi) tab2b;
    val tab2ca = V.NTab.update (a_v, zero) tab2c;
in
(* IMPROVE: check the right results are produced, not just *some* matching! *)
val _ = Testing.test "match a 0 = SOME ..." 
        (fn () => let val SOME x = E.match a zero E.empty_match; 
         in () end) ();
        (* a => (0) - (0) *)

val _ = Testing.test "match (a + b) 0 = SOME ..." 
        (fn () => let val SOME x = E.match (a + b) zero E.empty_match; 
         in () end) ();
        (* a => (0) - (b) *)

val _ = Testing.test "match (a + b) a = SOME ..." 
        (fn () => let val SOME x = E.match (a + b) a E.empty_match; 
         in () end) ();
        (*  a => (a) - (b) *)

val _ = Testing.test "match a (a + b) = SOME ..." 
        (fn () => let val SOME x = E.match a (a + b) E.empty_match; 
         in () end) ();
        (* a => (a + b) - (0) *)

val _ = Testing.test "match 0 a = false" 
        (fn () => let val NONE = E.match zero a E.empty_match; 
         in () end) ();

val _ = Testing.assert_no_failed_tests();
val _ = "UNIT TESTS FOR LinratExpr PASSED!";
end;
