// The following code is common to *any* custom op. This here is good to
// understand so you know what you're doing, but should not need editing.

#if !defined(USE_CUSTOM_OPS) && defined(cv_set_call_checker) && defined(XopENTRY_set)
#define USE_CUSTOM_OPS
#endif

#ifdef USE_CUSTOM_OPS //  USE_CUSTOM_OPS

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
        /*** entersub( list( push, arg1, ..., argN, cv ) ) */
        /* Though in rare cases it can also look like this: */
        /*** entersub( push, arg1, ..., argN, cv ) */
        /* Note also that there may not necessarily be any args. */

        /* first, get the real pushop, after which comes the arg list */
        OP *pushop = cUNOPx( entersubop )->op_first;    /* Cast the entersub op as an op with a single child
                                                           and get that child (the args list or pushop). */
        if( !OpHAS_SIBLING( pushop ) )          /* Go one layer deeper to get at the real pushop. */
          pushop = cUNOPx( pushop )->op_first;  /* (Sometimes not necessary when pushop is directly on entersub.) */

        /* identify the arg list details */
        OP *firstargop, *lastargop, *cvop;
        int nargs = find_arg_list_details( pushop, &firstargop, &lastargop, &cvop );
        /*** entersub( list( push, arg1, arg2, arg3, cv ) ) + ( arg1, arg2, arg3, cv ) */

        /* default to the original XS function if the arg count doesn't match */
        if(UNLIKELY(nargs != (int)CvPROTOLEN(ckobj)))
          return entersubop;

        /* and prepare to delete the other ops */

        OpMORESIB_set( pushop, cvop ); /* Replace the first op of the arg list with the cvop, which allows
                                          recursive deletion of all unneeded ops while keeping the arg list. */
        /*** entersub( list( push, cv ) ) + ( arg1, arg2, arg3, cv ) */

        if( lastargop ) // only try and cut the cv off the arg list if we have an arg list
          OpLASTSIB_set( lastargop, NULL ); /* Remove the trailing cv op from the arg list,
                                               by declaring the last arg to be the last sibling in the arg list. */
        /*** entersub( list( push, cv ) ) + ( arg1, arg2, arg3 ) */

        op_free( entersubop );    /* Recursively free entersubop + children, as it'll be replaced by the op we return. */
        /*** ( arg1, arg2, arg3 ) */

        /* create and return new op */
        OP *newop = firstargop ? newUNOP( OP_NULL, 0, firstargop ) : newOP( OP_NULL, 0 );
        newop->op_type   = OP_CUSTOM; /* can't do this in the new above, due to crashes pre-5.22 */
        /*** custom_op( arg1, arg2, arg3 ) */

        return newop;
    }

    /* This function interrogates the argument list of the function call, which
       can take any of these forms:
       * pushop, cvop
       * pushop, arg1, cvop
       * pushop, arg1, ..., argn, cvop
       The important questions we want answered are:
       * How many actual args are there? (To verify that it's called correctly.)
       * Where does the list of actual args start and end? (To be able to isolate
                                                            that for the new custom op.)
       * Where is the cvop? (To attach it on its own back to pushop and
                             recursively delete all the ops except for the args.)
       If there are no arguments as in the first form above, it only identifies
       cvop and returns a length of 0. */
    int
    find_arg_list_details( OP *pushop, OP **firstargop, OP **lastargop, OP **cvop )
    {
        OP *firstarg, *lastarg, *current;
        firstarg = lastarg = current = OpSIBLING( pushop );
        int nargs = 0;
        while( OpSIBLING( current ) )
        {
            nargs++;
            lastarg = current;
            current = OpSIBLING( current );
        }
        *cvop = current;
        if( nargs == 0 )
          return 0;

        *firstargop = firstarg;
        *lastargop = lastarg;
        return nargs;
    }

    // Installs the call checker and custom op onto the given xs function.
    static void
    install_xop(pTHX_ CV *cv, Perl_call_checker checker, const char *op_name, const char *op_desc, Perl_ppaddr_t ppfunc)
    {
        // tie op replacement function to XS function call
        cv_set_call_checker(cv, checker, (SV*)cv);

        // set up custom op structure, see perlguts.html#Custom-Operators
        static XOP xop;
        XopENTRY_set(&xop, xop_name, op_name);
        XopENTRY_set(&xop, xop_desc, op_desc);

        // register mix_pp as a custom op with Perl interpreter
        Perl_custom_op_register(aTHX_ ppfunc, &xop);
    }

#endif
