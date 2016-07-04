#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#if !defined(USE_CUSTOM_OPS) && defined(cv_set_call_checker) && defined(XopENTRY_set)
#define USE_CUSTOM_OPS
#endif

// original C function
int mix(int a, int b, int c) {
    a -= b; a -= c; a ^= (c>>13);
    b -= c; b -= a; b ^= (a<<8);
    c -= a; c -= b; c ^= (b>>13);
    a -= b; a -= c; a ^= (c>>12);
    b -= c; b -= a; b ^= (a<<16);
    c -= a; c -= b; c ^= (b>>5);
    a -= b; a -= c; a ^= (c>>3);
    b -= c; b -= a; b ^= (a<<10);
    c -= a; c -= b; c ^= (b>>15);
    return c;
}

// common XS code

#define MIX_XS                          \
    int c = POPi;                       \
    int b = POPi;                       \
    int a = POPi;                       \
    dXSTARG; /* required by PUSHi */    \
    PUSHi( mix(a, b, c) );

// fallback classic XS function definition

static void
THX_xsfunc_mix (pTHX_ CV *cv)
{
    dXSARGS;                                              // arg count is done explicitly here, but
    if (items != 3)                                             // handled by ck_entersub_args_proto at
       croak_xs_usage(cv,  "a, b, c");                          // compile time for the op
    MIX_XS;
    XSRETURN(1);
}

// preparations for custom op behavior starts here

#ifdef USE_CUSTOM_OPS //  USE_CUSTOM_OPS

    // custom op function, functionally equivalent to fallback XS function
    static OP *
    mix_pp(pTHX)
    {
        dSP;     // prepare the stack for access
        MIX_XS;
        PUTBACK; // resynchronize the stack
        return NORMAL; // let the op tree processor know this op completed successfully
    }

    // This function extracts the args for the custom op, deletes the remaining
    // ops from memory, and constructs a new custom op which will replace the
    // original entersub op.
    // Note that this is a generalized function which returns the custom op
    // without a function attached. You will need to do this attaching in a
    // a function-specific wrapper.
    static OP *
    THX_ck_entersub_args(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
    {
        /* fix up argument structures */
        entersubop = ck_entersub_args_proto(entersubop, namegv, ckobj);

        /* These comments will visualize how the op tree look like after
           each operation. We usually start out with this: */
        /*** entersub( list( push, arg1, arg2, arg3, cv ) ) */
        /* Though in rare cases it can also look like this: */
        /*** entersub( push, arg1, arg2, arg3, cv ) */

        /* first, get the real pushop, after which comes the arg list */
        OP *pushop = cUNOPx( entersubop )->op_first;    /* Cast the entersub op as an op with a single child
                                                           and get that child (the args list or pushop). */
        if( !OpHAS_SIBLING( pushop ) )          /* Go one layer deeper to get at the real pushop. */
          pushop = cUNOPx( pushop )->op_first;  /* (Sometimes not necessary when pushop is directly on entersub.) */

        /* then isolate the arg list */
        OP *firstargop = OpSIBLING( pushop );  /* Get a pointer to the first arg op
                                                  so we can attach it to the custom op later on. */
        /*** entersub( list( push, arg1, arg2, arg3, cv ) ) + ( arg1, arg2, arg3, cv ) */

        /* identify cvop (the last thing on the arg list) */
        OP *cvop;
        for (cvop = firstargop; OpSIBLING( cvop ); cvop = OpSIBLING( cvop )) ;

        /* identify the last actual arg */
        OP *lastargop, *argop;
        int nargs;
        for (nargs = 0, lastargop = pushop, argop = firstargop;
             argop != cvop;
             lastargop = argop, argop = OpSIBLING( argop ))
                nargs++;
        if(UNLIKELY(nargs != (int)CvPROTOLEN(ckobj))) return entersubop;

        /* and prepare to delete the other ops */
        OpMORESIB_set( pushop, cvop ); /* Replace the first op of the arg list with the cvop, which allows
                                          recursive deletion of all unneeded ops while keeping the arg list. */
        /*** entersub( list( push, cv ) ) + ( arg1, arg2, arg3, cv ) */

        OpLASTSIB_set( lastargop, NULL ); /* Remove the trailing cv op from the arg list,
                                             by declaring the last arg to be the last sibling in the arg list. */
        /*** entersub( list( push, cv ) ) + ( arg1, arg2, arg3 ) */

        op_free( entersubop );    /* Recursively free entersubop + children, as it'll be replaced by the op we return. */
        /*** ( arg1, arg2, arg3 ) */

        /* create and return new op */
        OP *newop = newUNOP( OP_NULL, 0, firstargop );
        newop->op_type   = OP_CUSTOM; /* can't do this in the new above, due to crashes pre-5.22 */
        /*** custom_op( arg1, arg2, arg3 ) */

        return newop;
    }

    // This is the wrapper function which creates a new custom op and attaches
    // the right op function to it.
    static OP *
    THX_ck_entersub_args_mix(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
    {
        OP *newop = THX_ck_entersub_args(aTHX_ entersubop, namegv, ckobj );
        newop->op_ppaddr = mix_pp;
        return newop;
    }

#endif

// XS module definition

MODULE = Hello::World		PACKAGE = Hello::World

PROTOTYPES: DISABLE

BOOT:
    {
    // Installs a classic XS function and returns its CV for later use,
    // provided by ExtUtils::ParseXS::Utilities::standard_XS_defs.
    CV *cv_mix = newXSproto_portable(
        "Hello::World::mix", THX_xsfunc_mix, __FILE__, "$$$"
    );
#ifdef USE_CUSTOM_OPS // ! USE_CUSTOM_OPS
        // tie op replacement function to XS function call
        cv_set_call_checker(cv_mix, THX_ck_entersub_args_mix, (SV*)cv_mix);
        // set up custom op structure, see perlguts.html#Custom-Operators
        static XOP mix_xop;
        XopENTRY_set(&mix_xop, xop_name, "mix_xop");
        XopENTRY_set(&mix_xop, xop_desc, "OP DESCRIPTION HERE");
        // register mix_pp as a custom op with Perl interpreter
        Perl_custom_op_register(aTHX_ mix_pp, &mix_xop);
#endif // ! USE_CUSTOM_OPS
    }
