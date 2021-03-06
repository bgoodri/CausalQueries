#' Restrict a model
#'
#' Restrict a model's parameter space. This reduces the number of nodal types and in consequence the number of unit causal types.
#'
#' Restrictions are made to nodal types, not to unit causal types. Thus for instance in a
#' model \code{X -> M -> Y}, one cannot apply a simple restriction so that \code{Y} is nondecreasing
#' in  \code{X}, however one can restrict so that \code{M} is nondecreasing in \code{X} and \code{Y} nondecreasing in \code{M}.
#' To have a restriction that \code{Y} be nondecreasing in \code{X} would otherwise require restrictions on causal types, not nodal types,
#' which implies a form of undeclared confounding (i.e. that in cases in which \code{M} is decreasing in \code{X}, \code{Y} is decreasing in \code{M}).
#'
#' Since restrictions are to nodal types, all parents of a node are implicitly fixed.  Thus for model \code{make_model(`X -> Y <- W`)} the request
#' \code{set_restrictions(`(Y[X=1] == 0)`)}
#' is interpreted as \code{set_restrictions(`(Y[X=1, W=0] == 0 | Y[X=1, W=1] == 0)`)}.
#'
#'
#' Statements with implicitly controlled nodes should be surrounded by parentheses, as in these examples.
#'
#'
#' Note that prior probabilities are redistributed over remaining types.
#'
#'
#' @inheritParams CausalQueries_internal_inherit_params
#' @param statement  A quoted expressions defining the restriction. If values for some parents are not specified, statements should be surrounded by parentheses, for instance \code{(Y[A = 1] > Y[A=0])} will be interpreted for all combinations of other parents of Y set at possible levels they might take.
#' @param join_by A string. The logical operator joining expanded types when \code{statement} contains wildcard (\code{.}). Can take values \code{'&'} (logical AND) or \code{'|'} (logical OR). When restriction contains wildcard (\code{.}) and \code{join_by} is not specified, it defaults to \code{'|'}, otherwise it defaults to \code{NULL}. Note that join_by joins within statements, not across statements.
#' @param labels A list of character vectors specifying nodal types to be kept or removed from the model. Use \code{get_nodal_types} to see syntax. Note that \code{labels} gets overwritten by \code{statement} if \code{statement} is not NULL.
#' @param keep Logical. If `FALSE`, removes and if `TRUE` keeps only causal types specified by \code{statement} or \code{labels}.
#'
#' @family restrictions
#'
#' @export
#' @return An object of class \code{model}. The causal types and nodal types in the model are reduced according to the stated restriction.
#'
#' @examples
#'
#' # 1. Restrict parameter space using statements
#' model <- make_model('X->Y') %>%
#'   set_restrictions(statement = c('X[] == 0'))
#'
#' model <- make_model('X->Y') %>%
#'   set_restrictions(non_increasing('X', 'Y'))
#'
#' model <- make_model('X -> Y <- W') %>%
#'   set_restrictions(c(decreasing('X', 'Y'), substitutes('X', 'W', 'Y')))
#'
#' model$parameters_df
#'
#' model <- make_model('X-> Y <- W') %>%
#'   set_restrictions(statement = decreasing('X', 'Y'))
#' model$parameters_df
#'
#' model <- make_model('X->Y') %>%
#'   set_restrictions(decreasing('X', 'Y'))
#' model$parameters_df
#'
#' model <- make_model('X->Y') %>%
#'   set_restrictions(c(increasing('X', 'Y'), decreasing('X', 'Y')))
#' model$parameters_df
#' \donttest{
#' # Restrict to define a model with monotonicity
#' model <- make_model('X->Y') %>%
#' set_restrictions(statement = c('Y[X=1] < Y[X=0]'))
#' get_parameter_matrix(model)
#'
#' # Restrict to a single type in endogenous node
#' model <- make_model('X->Y') %>%
#' set_restrictions(statement =  '(Y[X = 1] == 1)', join_by = '&', keep = TRUE)
#' get_parameter_matrix(model)
#'
#'#  Use of | and &
#'# Keep node if *for some value of B* Y[A = 1] == 1
#'model <- make_model('A->Y<-B') %>%
#' set_restrictions(statement =  '(Y[A = 1] == 1)', join_by = '|', keep = TRUE)
#'dim(get_parameter_matrix(model))
#'
#'
#'# Keep node if *for all values of B* Y[A = 1] == 1
#'model <- make_model('A->Y<-B') %>%
#' set_restrictions(statement =  '(Y[A = 1] == 1)', join_by = '&', keep = TRUE)
#' dim(get_parameter_matrix(model))
#'
#' # Restrict multiple nodes
#' model <- make_model('X->Y<-M; X -> M' ) %>%
#' set_restrictions(statement =  c('(Y[X = 1] == 1)', '(M[X = 1] == 1)'), join_by = '&', keep = TRUE)
#' get_parameter_matrix(model)
#'
#' # Restrictions on levels for endogenous nodes aren't allowed
#' \dontrun{
#' model <- make_model('X->Y') %>%
#' set_restrictions(statement =  '(Y == 1)')
#' }
#'
#' # 2. Restrict parameter space Using labels:
#' model <- make_model('X->Y') %>%
#' set_restrictions(labels = list(X = '0', Y = '00'))
#'
#' # Restrictions can be  with wildcards
#' model <- make_model('X->Y') %>%
#' set_restrictions(labels = list(Y = '?0'))
#' get_parameter_matrix(model)
#'
#' # Running example: there are only four causal types
#' model <- make_model('S -> C -> Y <- R <- X; X -> C -> R') %>%
#' set_restrictions(labels = list(C = '1000', R = '0001', Y = '0001'), keep = TRUE)
#' get_parameter_matrix(model)
#'}
set_restrictions <- function(model, statement = NULL, join_by = "|", labels = NULL, keep = FALSE) {


    is_a_model(model)
    nodal_types0 <- model$nodal_types

    if (!is.logical(keep))
        stop("`keep` should be either 'TRUE' or 'FALSE'")

    if (is.null(labels) & is.null(statement)) {
        message("No restrictions provided: provide either a causal statement or nodal type labels.")
        return(model)
    }

    if (!is.null(labels) & !is.null(statement)) {
        message("Provide either a causal statement or nodal type labels, not both.")
        return(model)
    }

    # Labels
    if (!is.null(labels))
        model <- restrict_by_labels(model, labels = labels, keep = keep)

    # Statement
    if (!is.null(statement))
        model <- restrict_by_query(model, statement = statement, join_by = join_by, keep = keep)

    # Remove spare P matrix columns for causal types for which there are no component nodal types
    if (!is.null(model$P)) {
        remaining_causal_type_names <- rownames(update_causal_types(model))
        model$P <- model$P[, colnames(model$P) %in% remaining_causal_type_names]
    }

    # Remove any spare P matrix / parameters_df param_families
    if (!is.null(model$P)) {

        # Drop family if an entire set is empty
        sets <- unique(model$parameters_df$param_set)
        to_keep <- sapply(sets, function(j) sum(model$P[model$parameters_df$param_set == j, ]) > 0)
        if (!all(to_keep)) {
            keep <- model$parameters_df$param_set %in% sets[to_keep]
            model$parameters_df <- dplyr::filter(model$parameters_df, keep)
            model$P <- model$P[keep, ]
        }
    }

    # Keep restricted types as attributes
    nodal_types1 <- model$nodal_types
    restrictions <- sapply(model$nodes, function(node) {
        restricted <- !nodal_types0[[node]] %in% nodal_types1[[node]]
        nodal_types0[[node]][restricted]
    }, simplify = FALSE, USE.NAMES = TRUE)

    restrictions <- Filter(length, restrictions)
    if (is.null(attr(model, "restrictions"))) {
        attr(model, "restrictions") <- restrictions
    } else {
        restrictions0 <- attr(model, "restrictions")
        attr(model, "restrictions") <- sapply(model$nodes, function(node) {
            c(restrictions[[node]], restrictions0[[node]])
        }, simplify = FALSE, USE.NAMES = TRUE)
    }

    return(model)
}


#' Reduce nodal types
#'
#' @param model a model created by make_model()
#' @param statement a list of character vectors specifying nodal types to be removed from the model. Use \code{get_nodal_types} to see syntax.
#' @param join_by A string or a list of strings. The logical operator joining expanded types when \code{statement} contains wildcard (\code{.}). Can take values \code{'&'} (logical AND) or \code{'|'} (logical OR). When restriction contains wildcard (\code{.}) and \code{join_by} is not specified, it defaults to \code{'|'}, otherwise it defaults to \code{NULL}.
#' @param keep Logical. If `FALSE`, removes and if `TRUE` keeps only causal types specified by \code{restriction}.
#' @return An object of class \code{causal_model}. The causal types and nodal types in the model are reduced according to the stated restriction.
#' @keywords internal
#' @family restrictions

restrict_by_query <- function(model, statement, join_by = "|", keep = FALSE) {

    # nodal_types <- get_nodal_types(model)
    nodal_types <- model$nodal_types

    n_restrictions <- length(statement)

    if (length(join_by) == 1) {
        join_by <- rep(join_by, n_restrictions)
    } else if (length(join_by) != n_restrictions) {
        stop(paste0("Argument `join_by` must be either of length 1 or have the same lenght as `restriction` argument."))
    }

    restrictions_list <- lapply(1:n_restrictions, function(i) {
        map_query_to_nodal_type(model, query = statement[i], join_by = join_by[i])
    })

    nodes_list <- sapply(restrictions_list, function(r) r$node)

    restrictions_list2 <- lapply(restrictions_list, function(x) names(x$types)[x$types])

    names(restrictions_list2) <- nodes_list
    unique_nodes <- unique(nodes_list)

    # Run through unique nodes and get all restricted types for the node
    selected_types <- sapply(unique_nodes, function(node) {
        i <- which(nodes_list == node)
        rl <- restrictions_list[i]
        unique(unlist(c(sapply(rl, function(x) names(x$types)[x$types]))))
    }, simplify = FALSE)

    # Clean up: Go through each node; figure out what to drop Remove from parameters_df and P matrix
    for (node in unique_nodes) {

        kept_types <- (nodal_types[[node]] %in% selected_types[[node]])

        if (!keep) {
            kept_types <- !kept_types
        }

        if (sum(kept_types) == 0) {
            stop(paste0("nodal_types can't be entirely reduced. Revise conditions for node ", node))
        }

        # What to keep in nodal_types
        kept_labels <- nodal_types[[node]][kept_types]  # to be used for P
        drop_labels <- nodal_types[[node]][!kept_types]  # to be used for P

        # Adjust nodal_types
        nodal_types[[node]] <- kept_labels
        model$nodal_types <- nodal_types

        # Adjust P: What to drop
        drop_rows <- (model$parameters_df$nodal_type %in% drop_labels) & (model$parameters_df$node %in%
            node)

        # Now drop
        model$parameters_df <- model$parameters_df %>% dplyr::filter(!drop_rows) %>% clean_params(warning = FALSE)

        if (!is.null(model$P))
            model$P <- model$P[!drop_rows, ]


    }
    model$causal_types <- update_causal_types(model)
    model
}


#' Reduce nodal types using labels
#'
#' @inheritParams CausalQueries_internal_inherit_params
#'
#' @param labels A list of character vectors specifying nodal types to be kept or removed from the model.
#' @param keep Logical. If `FALSE`, removes and if `TRUE` keeps only causal types specified by \code{restriction}.
#' @return An object of class \code{causal_model}. The causal types and nodal types in the model are reduced according to the stated restriction.
#' @keywords internal
#' @family restrictions

restrict_by_labels <- function(model, labels, keep = FALSE) {

    # Stop if none of the names of the labels vector matches nodes in dag Stop if there's any labels
    # name that doesn't match any of the nodes in the dag
    restricted_vars <- names(labels)
    matches <- restricted_vars %in% model$nodes

    if (!any(matches))
        stop("Variables ", paste(names(labels[!matches]), "are not part of the model."))

    # If there are wild cards, spell them out
    labels <- lapply(labels, function(j) unique(unlist(sapply(j, unpack_wildcard))))


    for (i in restricted_vars) {
        check <- model$parameters_df %>%
            filter(node==i)
        check <- check$nodal_type
        labels_passed <- unlist(labels[[i]])
        if (!all (labels_passed %in% check))
            stop("labels passed are not mapped to nodal_type. Check model$parameters_df")
    }

    # Reduce nodal_types
    for (k in 1:length(restricted_vars)) {
        j <- restricted_vars[k]
        nt <- model$nodal_types[[j]]
        if (!keep)
            to_keep <- nt[!(nt %in% labels[[k]])]
        if (keep)
            to_keep <- nt[nt %in% labels[[k]]]
        model$nodal_types[[j]] <- to_keep
        model$parameters_df <- dplyr::filter(model$parameters_df, !(node == j & !(nodal_type %in% to_keep)))
    }

    model$causal_types <- update_causal_types(model)
    model$parameters_df <- clean_params(model$parameters_df, warning = FALSE)

    return(model)

}


#' Get type names
#' @param nodal_types Nodal types of a model. See \code{\link{get_nodal_types}}.
#' @return A vector containing causal type names
#' @keywords internal
#' @examples
#' model <- make_model('A->Y<-B')
#' CausalQueries:::get_type_names(model$nodal_types)
get_type_names <- function(nodal_types) {
    unlist(sapply(1:length(nodal_types), function(i) {
        name <- names(nodal_types)[i]
        a <- nodal_types[[i]]
        paste(name, a, sep = ".")
    }))
}


#' Unpack a wild card
#' @param x A character. A nodal type containing one or more wildcard characters '?' to be unpacked.
#' @return A type label with wildcard characters '?' substituted by 0 and 1.
#' @keywords internal


unpack_wildcard <- function(x) {
    splitstring <- strsplit(x, "")[[1]]
    n_wild <- sum(splitstring == "?")
    if (n_wild == 0)
        return(x)
    variations <- perm(rep(1, n_wild))
    apply(variations, 1, function(j) {
        z <- splitstring
        z[z == "?"] <- j
        paste0(z, collapse = "")
    })
}

#' Update causal types based on nodal types
#' @inheritParams CausalQueries_internal_inherit_params
#' @return A \code{data.frame} containing updated causal types in a model
#' @keywords internal
#' @examples
#' CausalQueries:::update_causal_types(make_model('X->Y'))

update_causal_types <- function(model) {

    possible_types <- get_nodal_types(model)


    # Remove var name prefix from nodal types (Y00 -> 00) possible_types <- lapply(nodes, function(v)
    # gsub(v, '', possible_types[[v]])) names(possible_types) <- nodes

    # Get types as the combination of nodal types/possible_data. for X->Y: X0Y00, X1Y00, X0Y10, X1Y10...
    df <- data.frame(expand.grid(possible_types, stringsAsFactors = FALSE))

    # Add names
    cnames <- causal_type_names(df)
    rownames(df) <- do.call(paste, c(cnames, sep = "."))

    # Export
    df

}
