#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#if defined(cv_set_call_checker) && defined(XopENTRY_set)
# define USE_CUSTOM_OPS 1
#else
# define USE_CUSTOM_OPS 0
#endif

// fallback classic XS function definition

static void
THX_xsfunc_is_arrayref (pTHX_ CV *cv)
{
    dXSARGS;
    if (items != 1)
        Perl_croak(aTHX_ "Usage: Ref::Util::is_arrayref(ref)");
    SV *ref = POPs;
    SV *res = (SvROK(ref) && (SvTYPE(SvRV(ref)) == SVt_PVAV)) ? &PL_sv_yes : &PL_sv_no;
    PUSHs( res );
}

// preparations for custom op behavior starts here

#if USE_CUSTOM_OPS //  USE_CUSTOM_OPS

    // custom op function, functionally equivalent to fallback XS function
    static OP *
    is_arrayref_pp(pTHX)
    {
        dSP;
        SV *ref = POPs;
        SV *res = (SvROK(ref) && (SvTYPE(SvRV(ref)) == SVt_PVAV)) ? &PL_sv_yes : &PL_sv_no;
        PUSHs( res );
        PUTBACK;
        return NORMAL;
    }

    // This function extracts the args for the custom op, and deletes the remaining
    // ops from memory, so they can then be replaced entirely by the custom op.
    static OP *
    THX_ck_entersub_args_is_arrayref(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
    {
        /* fix up argument structures */
        entersubop = ck_entersub_args_proto(entersubop, namegv, ckobj);

        /* extract the args for the custom op, and delete the remaining ops
           NOTE: this is the *single* arg version, multi-arg is more
           complicated, see Hash::SharedMem's THX_ck_entersub_args_hsm */

        /* These comments will visualize how the op tree look like after
           each operation. We usually start out with this: */
        /*** entersub( list( push, arg1, cv ) ) */
        /* Though in rare cases it can also look like this: */
        /*** entersub( push, arg1, cv ) */

        /* first, get the real pushop, after which comes the arg list */
        OP *pushop = cUNOPx( entersubop )->op_first;    /* Cast the entersub op as an op with a single child
                                                           and get that child (the args list or pushop). */
        if( !OpHAS_SIBLING( pushop ) )          /* Go one layer deeper to get at the real pushop. */
          pushop = cUNOPx( pushop )->op_first;  /* (Sometimes not necessary when pushop is directly on entersub.) */

        /* then extract the arg */
        OP *arg = OpSIBLING( pushop );  /* Get a pointer to the first arg op
                                           so we can attach it to the custom op later on. */
        /*** entersub( list( push, arg1, cv ) ) + ( arg1, cv ) */

        /* and prepare to delete the other ops */
        OpMORESIB_set( pushop, OpSIBLING( arg ) ); /* Replace the first op of the arg list with the last arg op
                                                      (the cv op, i.e. pointer to original xs function),
                                                      which allows recursive deletion of all unneeded ops
                                                      while keeping the arg list. */
        /*** entersub( list( push, cv ) ) + ( arg1, cv ) */

        OpLASTSIB_set( arg, NULL ); /* Remove the trailing cv op from the arg list,
                                       by declaring the arg to be the last sibling in the arg list. */
        /*** entersub( list( push, cv ) ) + ( arg1 ) */

        op_free( entersubop );    /* Recursively free entersubop + children, as it'll be replaced by the op we return. */
        /*** ( arg1 ) */

        /* create and return new op */
        OP *newop = newUNOP( OP_NULL, 0, arg );
        newop->op_type   = OP_CUSTOM; /* can't do this in the new above, due to crashes pre-5.22 */
        newop->op_ppaddr = is_arrayref_pp;
        /*** custom_op( arg1 ) */

        return newop;
    }

#endif

// XS module definition

MODULE = Ref::Util		PACKAGE = Ref::Util

PROTOTYPES: DISABLE

BOOT:
    {
#if !USE_CUSTOM_OPS // ! USE_CUSTOM_OPS
        // installs a classic XS function, as per perlapi
        newXSproto(
            "Ref::Util::is_arrayref", THX_xsfunc_is_arrayref, __FILE__, "$"
        );
#else // ! USE_CUSTOM_OPS
        // installs an XS function and returns its CV for later use
        // provided by ExtUtils::ParseXS::Utilities::standard_XS_defs
        CV *cv = newXSproto_portable(
            "Ref::Util::is_arrayref", THX_xsfunc_is_arrayref, __FILE__, "$"
        );
        // tie op replacement function to XS function call
        cv_set_call_checker(cv, THX_ck_entersub_args_is_arrayref, (SV*)cv);
        // set up custom op structure, see perlguts.html#Custom-Operators
        static XOP is_arrayref_xop;
        XopENTRY_set(&is_arrayref_xop, xop_name, "is_arrayref_xop");
        XopENTRY_set(&is_arrayref_xop, xop_desc, "OP DESCRIPTION HERE");
        // register is_arrayref_pp as a custom op with Perl interpreter
        Perl_custom_op_register(aTHX_ is_arrayref_pp, &is_arrayref_xop);
#endif // ! USE_CUSTOM_OPS
    }
