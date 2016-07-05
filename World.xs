#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

// import common custom op functions
#include "custom_ops.c"

// The following code is specific to any given custom op.
//  Whenever you make a new custom op *everything* here needs touching.

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

double distance( double x1, double x2, double y1, double y2 ) {
    double distance_x = x1 - x2; // could be written with pow(), but that's slower
    double distance_y = y1 - y2;
    return sqrt( (distance_x * distance_x) + (distance_y * distance_y) );
}

// common XS code

static void
mix_xs(pTHX)
{
    dSP;     // prepare the stack for access
    int c = POPi;
    int b = POPi;
    int a = POPi;
    dXSTARG; /* required by PUSHi */
    PUSHi( mix(a, b, c) );
    PUTBACK; // resynchronize the stack
}

static void
distance_xs(pTHX)
{
    dSP;     // prepare the stack for access
    int y2 = POPn;
    int y1 = POPn;
    int x2 = POPn;
    int x1 = POPn;
    dXSTARG; /* required by PUSHi */
    PUSHn( distance( x1, x2, y1, y2 ) );
    PUTBACK; // resynchronize the stack
}

// fallback classic XS function definition

static void
THX_xsfunc_mix (pTHX_ CV *cv)
{
    dXSARGS;                                              // arg count is done explicitly here, but
    if (items != 3)                                             // handled by ck_entersub_args_proto at
       croak_xs_usage(cv,  "a, b, c");                          // compile time for the op
    mix_xs(aTHX);
}

static void
THX_xsfunc_distance (pTHX_ CV *cv)
{
    dXSARGS;                                              // arg count is done explicitly here, but
    if (items != 4)                                             // handled by ck_entersub_args_proto at
       croak_xs_usage(cv,  "x1, x2, y1, y2");                          // compile time for the op
    distance_xs(aTHX);
}

// preparations for custom op behavior starts here

#ifdef USE_CUSTOM_OPS //  USE_CUSTOM_OPS

    // custom op function, functionally equivalent to fallback XS function
    static OP *
    mix_pp(pTHX)
    {
        mix_xs(aTHX);
        return NORMAL; // let the op tree processor know this op completed successfully
    }

    static OP *
    distance_pp(pTHX)
    {
        distance_xs(aTHX);
        return NORMAL; // let the op tree processor know this op completed successfully
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

    static OP *
    THX_ck_entersub_args_distance(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
    {
        OP *newop = THX_ck_entersub_args(aTHX_ entersubop, namegv, ckobj );
        newop->op_ppaddr = distance_pp;
        return newop;
    }

#endif

// XS module definition

MODULE = Hello::World		PACKAGE = Hello::World

PROTOTYPES: DISABLE

BOOT:
    {
        // newXSproto_portable installs a classic XS function and feeds its CV
        // to install_xs_func, if possible, which installs a call checker and
        // custom op that will replace the XS function at compile time.
        // newXSproto_portable provided by ExtUtils::ParseXS::Utilities::standard_XS_defs.
        CV *mix_cv = newXSproto_portable("Hello::World::mix", THX_xsfunc_mix, __FILE__, "$$$");
        CV *distance_cv = newXSproto_portable("Hello::World::distance", THX_xsfunc_distance, __FILE__, "$$$$");
#ifdef USE_CUSTOM_OPS // USE_CUSTOM_OPS
        install_xop(aTHX_ mix_cv, THX_ck_entersub_args_mix, "mix_xop", "mix does some math", mix_pp);
        install_xop(aTHX_ distance_cv, THX_ck_entersub_args_distance, "distance_xop", "distance does some 2d math", distance_pp);
#endif // USE_CUSTOM_OPS
    }
