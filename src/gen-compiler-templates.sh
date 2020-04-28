#! /bin/sh

awk '
BEGIN	{
	base_class_f = "CompilerBaseDefs.h"
	sub_class_f = "CompilerSubDefs.h"
	ops_f = "CompilerOpsDefs.h"
	ops_names_f = "CompilerOpsNamesDefs.h"
	ops_eval_f = "CompilerOpsEvalDefs.h"
	vec1_eval_f = "CompilerVec1EvalDefs.h"
	vec2_eval_f = "CompilerVec2EvalDefs.h"
	methods_f = "CompilerOpsMethodsDefs.h"
	exprsC1_f = "CompilerOpsExprsDefsC1.h"
	exprsC2_f = "CompilerOpsExprsDefsC2.h"
	exprsC3_f = "CompilerOpsExprsDefsC3.h"
	exprsV_f = "CompilerOpsExprsDefsV.h"

	prep(exprsC1_f)
	prep(exprsC2_f)
	prep(exprsC3_f)
	prep(exprsV_f)

	args["X"] = "()"
	args["O"] = "(OpaqueVals* v)"
	args["V"] = "(const NameExpr* n)"
	args["VV"] = "(const NameExpr* n1, const NameExpr* n2)"
	args["VVV"] = "(const NameExpr* n1, const NameExpr* n2, const NameExpr* n3)"
	args["VVVV"] = "(const NameExpr* n1, const NameExpr* n2, const NameExpr* n3, const NameExpr* n4)"
	args["C"] = "(const ConstExpr* c)"
	args["VC"] = "(const NameExpr* n, ConstExpr* c)"
	args["VVC"] = "(const NameExpr* n1, const NameExpr* n2, ConstExpr* c)"
	args["VCV"] = "(const NameExpr* n1, ConstExpr* c, const NameExpr* n2)"

	args2["X"] = ""
	args2["O"] = "reg"
	args2["V"] = "n"
	args2["VV"] = "n1, n2"
	args2["VVV"] = "n1, n2, n3"
	args2["VVVV"] = "n1, n2, n3, n4"
	args2["C"] = "c"
	args2["VC"] = "n, c"
	args2["VVC"] = "n1, n2, c"
	args2["VCV"] = "n1, c, n2"

	exprC1["VC"] = "lhs, r1->AsConstExpr()";
	exprC1["VCV"] = "lhs, r1->AsConstExpr(), r2->AsNameExpr()"

	exprC2["VVC"] = "lhs, r1->AsNameExpr(), r2->AsConstExpr()"
	exprC2["VVCC"] = "lhs, r1->AsNameExpr(), r2->AsConstExpr(), r3->AsConstExpr()"
	exprC2["VVCV"] = "lhs, r1->AsNameExpr(), r2->AsConstExpr(), r3->AsNameExpr()"

	exprC3["VVVC"] = "lhs, r1->AsNameExpr(), r2->AsNameExpr(), r3->AsConstExpr()"

	exprV["X"] = ""
	exprV["V"] = "lhs"
	exprV["VV"] = "lhs, r1->AsNameExpr()"
	exprV["VVV"] = "lhs, r1->AsNameExpr(), r2->AsNameExpr()"
	exprV["VVVV"] = "lhs, r1->AsNameExpr(), r2->AsNameExpr(), r3->AsNameExpr()"

	accessors["I"] = ".int_val"
	accessors["U"] = ".uint_val"
	accessors["D"] = ".double_val"
	accessors["S"] = ".string_val"
	accessors["T"] = ".table_val"

	eval_selector["I"] = ""
	eval_selector["U"] = ""
	eval_selector["D"] = ""
	eval_selector["S"] = "S"
	eval_selector["T"] = "T"

	++no_vec["T"]

	# Suffix used for vector operations.
	vec = "_vec"
	}

$1 == "op"	{ dump_op(); op = $2; next }
$1 == "expr-op"	{ dump_op(); op = $2; expr_op = 1; next }
$1 == "unary-op"	{ dump_op(); op = $2; ary_op = 1; next }
$1 == "unary-expr-op"	{ dump_op(); op = $2; expr_op = 1; ary_op = 1; next }
$1 == "binary-expr-op"	{ dump_op(); op = $2; expr_op = 1; ary_op = 2; next }
$1 == "internal-op"	{ dump_op(); op = $2; internal_op = 1; next }

$1 == "type"	{ type = $2; next }
$1 == "vector"	{ vector = 1; next }
$1 ~ /^op-type(s?)$/	{ build_op_types(); next }
$1 == "opaque"	{ opaque = 1; next }
$1 ~ /^eval((_[ST])?)$/	{
		if ( $1 != "eval" )
			{
			# Extract subtype specifier.
			eval_sub = $1
			sub(/eval_/, "", eval_sub)

			if ( ! (eval_sub in eval_selector) ||
			     eval_selector[eval_sub] == "" )
				gripe("bad eval subtype specifier")
			}
		else
			eval_sub = ""

		new_eval = all_but_first()
		if ( ! operand_type || eval_sub )
			# Add semicolons for potentially multi-line evals.
			new_eval = new_eval ";"

		if ( eval[eval_sub] )
			{
			if ( operand_type && ! eval_sub )
				gripe("cannot intermingle op-type and multi-line evals")

			eval[eval_sub] = eval[eval_sub] "\n\t\t" new_eval

			# The following variables are just to enable
			# us to produce tidy-looking switch blocks.
			multi_eval = "\n\t\t"
			eval_blank = ""
			}
		else
			{
			eval[eval_sub] = new_eval
			eval_blank = " "
			}
		next
		}

$1 == "method-pre"	{ method_pre = all_but_first(); next }

/^#/		{ next }
/^[ \t]*$/	{ next }

	{ gripe("unrecognized compiler template line: " $0) }

END	{
	dump_op()

	finish(exprsC1_f, "C1")
	finish(exprsC2_f, "C2")
	finish(exprsC3_f, "C3")
	finish(exprsV_f, "V")
	}

function build_op_types()
	{
	operand_type = 1

	for ( i = 2; i <= NF; ++i )
		{
		if ( $i in accessors )
			++op_types[$i]
		else
			gripe("bad op-type " $i)
		}

	# The "rep" is simply one of the listed types, which we use
	# to generate the corresponding base method only once.
	op_type_rep = $2
	}

function all_but_first()
	{
	all = ""
	for ( i = 2; i <= NF; ++i )
		{
		if ( i > 2 )
			all = all " "

		all = all $i
		}

	return all
	}

function dump_op()
	{
	if ( ! op )
		return

	if ( ! ary_op )
		{
		build_op(op, type, "", eval[""], eval[""], 0, 0)
		clear_vars()
		return
		}

	if ( ! operand_type )
		# This op does not have "flavors".  Give it one
		# empty flavor to use in iterating.
		++op_types[""]

	# Note, for most operators the constant version would have
	# already been folded, but for some like AppendTo, they
	# cannot, so we account for that possibility here.

	for ( i in op_types )
		{
		sel = eval_selector[i]

		# Loop over constant, var for first operand
		for ( j = 0; j <= 1; ++j )
			{
			op1 = j ? "V" : "C"

			if ( ary_op == 1 )
				{
				ex = expand_eval(eval[sel], expr_op, i, j, 0)
				build_op(op, "V" op1, i, eval[sel], ex, j, 0)
				continue;
				}

			# Loop over constant, var for second operand
			for ( k = 0; k <= 1; ++k )
				{
				if ( ! j && ! k )
					# Do not generate CC, should have
					# been folded.
					continue;

				op2 = k ? "V" : "C"
				ex = expand_eval(eval[sel], expr_op, i, j, k)
				build_op(op, "V" op1 op2, i, eval[sel], ex, j, k)
				}
			}
		}

	clear_vars()
	}

function expand_eval(e, is_expr_op, otype, is_var1, is_var2)
	{
	accessor = ""
	expr_app = ""
	if ( otype )
		{
		if ( ! (otype in accessors) )
			gripe("bad operand_type: " otype)

		accessor = accessors[otype]
		expr_app = ";"
		}

	e_copy = e
	rep1 = "(" (is_var1 ? "frame[s.v2]" : "s.c") accessor ")"
	gsub(/\$1/, rep1, e_copy)

	if ( ary_op == 2 )
		{
		rep2 = "(" (is_var2 ? "frame[s.v3]" : "s.c") accessor ")"
		gsub(/\$2/, rep2, e_copy)
		}

	if ( is_expr_op )
		{
		if ( index(e_copy, "$$") > 0 )
			{
			e_copy = "delete frame[s.v1]" \
				accessor ";\n\t\t" e_copy
			gsub(/\$\$/, "frame[s.v1]" accessor, e_copy)
			return e_copy expr_app
			}
		else
			return "frame[s.v1]" accessor " = " e_copy expr_app
		}
	else
		return e_copy accessor
	}

function build_op(op, type, sub_type, orig_eval, eval, is_var1, is_var2)
	{
	if ( ! (type in args) )
		gripe("bad type " type " for " op)

	orig_op = op
	gsub(/-/, "_", op)
	upper_op = toupper(op)
	op_type = op type

	full_op = "OP_" upper_op "_" type
	full_op_no_sub = full_op
	if ( sub_type )
		full_op = full_op "_" sub_type

	# Track whether this is the "representative" operand for
	# operations with multiple types of operands.  This lets us
	# avoid redundant declarations.
	is_rep = ! sub_type || sub_type == op_type_rep
	do_vec = vector && ! no_vec[sub_type]

	if ( ! internal_op && is_rep )
		{
		print ("\tvirtual const CompiledStmt " \
			op_type args[type] " = 0;") >base_class_f
		print ("\tconst CompiledStmt " op_type args[type] \
			" override;") >sub_class_f

		if ( do_vec )
			{
			print ("\tvirtual const CompiledStmt " \
				op_type vec args[type] " = 0;") >base_class_f
			print ("\tconst CompiledStmt " op_type vec \
				args[type] " override;") >sub_class_f
			}
		}

	print ("\t" full_op ",") >ops_f
	if ( do_vec )
		print ("\t" full_op vec ",") >ops_f

	print ("\tcase " full_op ":\treturn \"" tolower(orig_op) \
		"-" type "\";") >ops_names_f
	if ( do_vec )
		print ("\tcase " full_op vec ":\treturn \"" tolower(orig_op) \
			"-" type "-vec" "\";") >ops_names_f

	print ("\tcase " full_op ":\n\t\t{ " \
		multi_eval eval multi_eval eval_blank \
		"}" multi_eval eval_blank "break;\n") >ops_eval_f

	if ( do_vec )
		{
		if ( ary_op == 1 )
			{
			print ("\tcase " full_op vec ":\n\t\tvec_exec(" full_op vec \
				", frame[s.v1].raw_vector_val,\n\t\t\t" \
				(is_var1 ? "frame[s.v2]" : "s.c") \
				".raw_vector_val);\n\t\tbreak;\n") >ops_eval_f

			# ### Here we know about the "accessor" global.
			oe_copy = orig_eval
			gsub(/\$1/, "(*v2)[i]" accessor, oe_copy)

			print ("\tcase " full_op vec ": (*v1)[i]" accessor " = " \
				oe_copy "; break;") >vec1_eval_f
			}

		else
			{
			### Right now we wind up generating 3 identical
			### case bodies for VCV, VVC, and VVV.  This gives
			### us some latitude in case down the line we
			### come up with a different vector scheme that
			### varies for constant vectors, but we could
			### consider compressing them down in the interest
			### of smaller code size.
			print ("\tcase " full_op vec ":\n\t\tvec_exec("  \
				full_op vec \
				",\n\t\t\tframe[s.v1].raw_vector_val,\n\t\t\t" \
				(is_var1 ? "frame[s.v2]" : "s.c") \
				".raw_vector_val, " \
				(is_var2 ? "frame[s.v3]" : "s.c") \
				".raw_vector_val);\n\t\tbreak;\n") >ops_eval_f

			oe_copy = orig_eval
			gsub(/\$1/, "(*v2)[i]" accessor, oe_copy)
			gsub(/\$2/, "(*v3)[i]" accessor, oe_copy)

			if ( eval_selector[sub_type] != "" )
				{
				### Need to resolve whether to "delete"
				### here.
				gsub(/\$\$/, "(*v1)[i]" accessor, oe_copy)
				print ("\tcase " full_op vec ":\n\t\t{\n\t\t" \
					oe_copy "\n\t\tbreak;\n\t\t}") >vec2_eval_f
				}

			else
				print ("\tcase " full_op vec ":\n\t\t(*v1)[i]" \
					accessor " = " \
					oe_copy "; break;") >vec2_eval_f
			}
		}


	if ( ! internal_op && is_rep )
		{
		gen_method(full_op_no_sub, full_op, type, sub_type,
				0, method_pre)

		if ( do_vec )
			gen_method(full_op_no_sub, full_op, type, sub_type,
					1, method_pre)
		}

	if ( expr_op && is_rep )
		{
		if ( type == "C" )
			gripe("bad type " type " for expr " op)

		expr_case = "EXPR_" upper_op

		if ( type in exprC1 )
			{
			eargs = exprC1[type]
			f = exprsC1_f
			}

		else if ( type in exprC2 )
			{
			eargs = exprC2[type]
			f = exprsC2_f
			}

		else if ( type in exprC3 )
			{
			eargs = exprC3[type]
			f = exprsC3_f
			}

		else if ( type in exprV )
			{
			eargs = exprV[type]
			f = exprsV_f
			}

		else
			gripe("bad type " type " for expr " op)

		if ( do_vec )
			{
			print ("\tcase " expr_case ":\n\t\t" \
				"if ( rt->Tag() == TYPE_VECTOR )\n\t\t\t" \
				"return c->" op_type vec "(" eargs ");\n" \
				"\t\telse\n\t\t\t" \
				"return c->" op_type "(" eargs ");") >f
			}

		else
			print ("\tcase " expr_case ":\treturn c->" \
				op_type "(" eargs ");") >f
		}
	}

function gen_method(full_op_no_sub, full_op, type, sub_type, is_vec, method_pre)
	{
	print ("const CompiledStmt AbstractMachine::" \
		(op_type (is_vec ? vec : "")) args[type]) >methods_f

	print ("\t{") >methods_f
	if ( method_pre )
		print ("\t" method_pre ";") >methods_f

	if ( type == "O" )
		print ("\treturn AddStmt(AbstractStmt(" \
			full_op ", reg));") >methods_f

	else if ( args2[type] != "" )
		{
		# This is the only scenario where sub_type should occur.
		part1 = "\treturn AddStmt(GenStmt(this, "
		part2 = ", " args2[type] "));"

		if ( sub_type )
			{
			# Only works for unary.
			op1_is_const = type ~ /^VC/
			test_var = op1_is_const ? "c" : "n2"
			print ("\tauto t = " test_var "->Type();") >methods_f
			print ("\tauto tag = t->Tag();") >methods_f
			print ("\tauto i_t = t->InternalType();") >methods_f

			n = 0;
			for ( o in op_types )
				{
				if ( is_vec && no_vec[o] )
					continue

				else_text = ((++n > 1) ? "else " : "");
				if ( o == "I" || o == "U" )
					{
					print ("\t" else_text "if ( i_t == TYPE_INTERNAL_INT || i_t == TYPE_INTERNAL_UNSIGNED )") >methods_f
					}
				else if ( o == "D" )
					print ("\t" else_text "if ( i_t == TYPE_INTERNAL_DOUBLE )") >methods_f
				else if ( o == "S" )
					print ("\t" else_text "if ( i_t == TYPE_INTERNAL_STRING )") >methods_f
				else if ( o == "T" )
					print ("\t" else_text "if ( tag == TYPE_TABLE )") >methods_f
				else
					gripe("bad subtype " o)

				print ("\t" part1 \
					(full_op_no_sub \
					 "_" o (is_vec ? vec : "")) \
					part2) >methods_f
				}

			print ("\telse\n\t\treporter->InternalError(\"bad internal type\");") >methods_f
			}
		else
			print (part1 full_op part2) >methods_f
		}
	else
		print ("\treturn AddStmt(GenStmt(this, \
			" full_op "));") >methods_f

	print ("\t}\n") >methods_f
	}

function clear_vars()
	{
	opaque = type = multi_eval = eval_blank = method_pre = ""
	vector = internal_op = ary_op = expr_op = op = ""
	operand_type = ""
	delete eval
	delete op_types
	}

function prep(f)
	{
	print ("\t{") >f
	print ("\tswitch ( rhs->Tag() ) {") >f
	}

function finish(f, which)
	{
	print ("\tdefault:") >f
	print ("\t\treporter->InternalError(\"inconsistency in " which " AssignExpr::Compile\");") >f
	print ("\t}\t}") >f
	}

function gripe(msg)
	{
	print "error at input line", NR ":", msg
	exit(1)
	}
' $*