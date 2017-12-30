/*# /=====================================================================\ #
  # |  LaTeXML/src/errors.h                                               | #
  # |                                                                     | #
  # |=====================================================================| #
  # | Part of LaTeXML:                                                    | #
  # |  Public domain software, produced as part of work done by the       | #
  # |  United States Government & not subject to copyright in the US.     | #
  # |---------------------------------------------------------------------| #
  # | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
  # | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
  # \=========================================================ooo==U==ooo=/ # */

/*======================================================================
  C-level Error handling support */

/* This should evolve to provide an API to Error.pm,
   or possibly replace it
   or at the very least, generate messages that cooperate with it.
   Calls to croak in src should end up calling something here.

   Calls from XS functions can access cv to get (some) calling context.
   How can calls from within the C do this?
   Or more importantly: How to I establish a context that tells the User/Programmer
   where the problem stems from? Somewhere in Perl or TeX ??? 
   At least, what token is being expanded or processed?
*/
#ifndef ERRORS_H
#define ERRORS_H

extern const char *
where_from_cv(pTHX_ const CV *const cv);

extern const char *
actualtype_from_sv(pTHX_ const SV *arg);

extern void *
typecheck_croak(pTHX_ const char * const what, const char * const actualtype,
                const char * const where, const char * const loc, 
                const char * const expected);

/* Most of these should move to thier respective *.h ? */
#define isa_undef(arg)        (!(arg) || !SvOK(arg))
#define isa_int(arg)          ((arg) && SvIOK(arg))
#define isa_double(arg)       ((arg) && SvNOK(arg))
#define isa_string(arg)       ((arg) && SvPOK(arg))
#define isa_CODE(arg)         ((arg) && SvROK(arg) && (SvTYPE(SvRV(arg)) == SVt_PVCV))
#define isa_Opcode(arg)       ((arg) && sv_isa(arg, "LaTeXML::Core::Opcode"))
#define isa_Definition(arg)   ((arg) && sv_derived_from(arg, "LaTeXML::Core::Definition"))
#define isa_Expandable(arg)   ((arg) && sv_isa(arg, "LaTeXML::Core::Definition::Expandable"))
#define isa_Primitive(arg)    ((arg) && sv_isa(arg, "LaTeXML::Core::Definition::Primitive"))
#define isa_Constructor(arg)  ((arg) && sv_isa(arg, "LaTeXML::Core::Definition::Constructor"))

#define isa_Model(arg)        ((arg) && sv_isa(arg, "LaTeXML::Common::Model"))
#define isa_Font(arg)         ((arg) && sv_isa(arg, "LaTeXML::Common::Font"))
#define isa_Box(arg)          ((arg) && sv_isa(arg, "LaTeXML::Core::Box"))
#define isa_List(arg)         ((arg) && sv_isa(arg, "LaTeXML::Core::List"))
#define isa_Whatsit(arg)      ((arg) && sv_isa(arg, "LaTeXML::Core::Whatsit"))
#define isa_KeyVals(arg)      ((arg) && sv_isa(arg, "LaTeXML::Core::KeyVals"))
#define isa_Comment(arg)      ((arg) && sv_isa(arg, "LaTeXML::Core::Comment"))

/* NOTE: This is Bizarre; it definitely needs cleanup!
   There are probably other types lurking out there.
   The issue is somewhat that they don't become "Box" when they get digested? */
#define isa_BoxLike(arg)      ((arg) && (sv_derived_from(arg, "LaTeXML::Core::Box") \
                                         || sv_isa(arg,"LaTeXML::Core::Pair") \
                                         || sv_isa(arg,"LaTeXML::Core::KeyVals") \
                                         ))

/* A varargs trick to avoid having to append the number of types. */

#define VA_NUM_ARGS(...) VA_NUM_ARGS_IMPL(__VA_ARGS__, 5,4,3,2,1)
#define VA_NUM_ARGS_IMPL(_1,_2,_3,_4,_5,N,...) N

#define macro_dispatcher(func, ...) \
            macro_dispatcher_(func, VA_NUM_ARGS(__VA_ARGS__))
#define macro_dispatcher_(func, nargs) \
            macro_dispatcher__(func, nargs)
#define macro_dispatcher__(func, nargs) \
            func ## nargs

#define isa_svtype1(arg,type)                                     \
  (isa_ ## type(arg))

#define isa_svtype2(arg,type1,type2)   \
  ((isa_ ## type1(arg)) || (isa_ ## type2(arg)))

#define isa_svtype3(arg,type1,type2,type3)               \
  ((isa_ ## type1(arg)) || (isa_ ## type2(arg)) || (isa_ ## type3(arg)))

#define isa_svtype4(arg,type1,type2,type3,type4)                       \
  ((isa_ ## type1(arg)) || (isa_ ## type2(arg)) || (isa_ ## type3(arg)) || (isa_ ## type4(arg)))

#define isa_svtype5(arg,type1,type2,type3,type4,type5)                  \
  ((isa_ ## type1(arg)) || (isa_ ## type2(arg)) || (isa_ ## type3(arg)) \
   || (isa_ ## type4(arg)) || (isa_ ## type5(arg)))

#define isa_svtype(arg,...) \
  macro_dispatcher(isa_svtype, __VA_ARGS__)(arg,__VA_ARGS__)


#define svtype_name1(type) \
  #type
#define svtype_name2(type1,type2) \
  #type1 " or " #type2
#define svtype_name3(type1,type2,type3) \
 #type1 ", " #type2 " or " #type3
#define svtype_name4(type1,type2,type3,type4) \
  #type1 ", " #type2 ", " #type3 " or " #type4
#define svtype_name5(type1,type2,type3,type4,type5) \
  #type1 ", " #type2 ", " #type3", " #type4 " or " #type5

#define svtype_name(...) \
  macro_dispatcher(svtype_name, __VA_ARGS__)(__VA_ARGS__)

#define source_location \
  source_locationX(__FILE__,__LINE__)
#define source_locationX(file,line)       \
  source_locationXX(file,line)
#define source_locationXX(file,line)      \
  " (in " #file " @ line " #line ")"

#define typecheck_fatal(arg,argname,where,...) \
  typecheck_croak(aTHX_ argname, actualtype_from_sv(aTHX_ arg),       \
                  where, source_location, svtype_name(__VA_ARGS__))

#define typecheck_xsfatal(arg,argname,...) \
  typecheck_croak(aTHX_ argname, actualtype_from_sv(aTHX_ arg),       \
                  where_from_cv(aTHX_ cv),"", svtype_name(__VA_ARGS__))

#define typecheck_xsarg(arg,...) \
  (isa_svtype(arg,__VA_ARGS__) ? arg \
   : typecheck_xsfatal(arg,"Argument " #arg,__VA_ARGS__))

/* Typical usage:
   char * value = (typecheck_optarg(3,string) ? SvPV_nolen(ST(3)) : NULL);
 */
#define typecheck_optarg(pos,argname,...)       \
  ((items > pos) && SvOK(ST(pos))               \
   && (isa_svtype(ST(pos),__VA_ARGS__) ? ST(pos) \
       : typecheck_xsfatal(ST(pos),"Argument " argname,__VA_ARGS__)))

/* Now we'll need similar tools for values RETURNED from call_sv, call_method
   And also for things extracted from HV, AV, and so on. */

#define typecheck_value(arg,argname,where,...)  \
  (isa_svtype(arg,__VA_ARGS__) ? arg \
   : typecheck_fatal(arg,argname,where,__VA_ARGS__))

#endif
