return {
    tex = {
        "btex", "etex", "verbatimtex",
    },
    shortcuts = {
        "..", "...", "--", "---", "&", "\\",
    },
    primitives = { -- to be checked
        "charcode", "day", "linecap", "linejoin", "miterlimit", "month", "pausing",
        "prologues", "showstopping", "time", "tracingcapsules", "tracingchoices", "mpprocset",
        "tracingcommands", "tracingequations", "tracinglostchars",
        "tracingmacros", "tracingonline", "tracingoutput", "tracingrestores",
        "tracingspecs", "tracingstats", "tracingtitles", "truecorners",
        "warningcheck", "year",
        "false", "nullpicture", "pencircle", "penspec", "true",
        "and", "angle", "arclength", "arctime", "ASCII", "boolean", "bot",
        "char", "color", "cosd", "cycle", "decimal", "directiontime", "floor", "fontsize",
        "hex", "infont", "intersectiontimes", "known", "length", "llcorner",
        "lrcorner", "makepath", "makepen", "mexp", "mlog", "normaldeviate", "not",
        "numeric", "oct", "odd", "or", "path", "pair", "pen", "penoffset", "picture", "point",
        "postcontrol", "precontrol", "reverse", "rotated", "scaled",
        "shifted", "sind", "slanted", "sqrt", "str", "string", "subpath", "substring",
        "transform", "transformed", "ulcorner", "uniformdeviate", "unknown",
        "urcorner", "xpart", "xscaled", "xxpart", "xypart", "ypart", "yscaled", "yxpart",
        "yypart", "zscaled",
        "addto", "clip", "input", "interim", "let", "newinternal", "save", "setbounds",
        "shipout", "show", "showdependencies", "showtoken", "showvariable",
        "special",
        "begingroup", "endgroup", "of", "curl", "tension", "and", "controls",
        "interpath", "on", "off",
        "def", "vardef", "enddef", "expr", "suffix", "text", "primary", "secondary",
        "tertiary", "primarydef", "secondarydef", "tertiarydef",
        "randomseed", "also", "contour", "doublepath",
        "withcolor", "withcmykcolor", "withpen",
        "dashed",
        "envelope",
        "if", "else", "elseif", "fi", "for", "endfor", "forever", "exitif", "within",
        "forsuffixes", "step", "until",
        "charlist", "extensible", "fontdimen", "headerbyte", "kern", "ligtable",
        "boundarychar", "chardp", "charext", "charht", "charic", "charwd", "designsize",
        "fontmaking", "charexists",
        "cullit", "currenttransform", "gfcorners", "grayfont", "hround",
        "imagerules", "lowres_fix", "nodisplays", "notransforms", "openit",
        "displaying", "currentwindow", "screen_rows", "screen_cols",
        "pixels_per_inch", "cull", "display", "openwindow", "numspecial",
        "totalweight", "autorounding", "fillin", "proofing", "tracingpens",
        "xoffset", "chardx", "granularity", "smoothing", "turningcheck", "yoffset",
        "chardy", "hppp", "tracingedges", "vppp",
        "extra_beginfig", "extra_endfig", "mpxbreak",
        "endinput",
        "message", "delimiters", "turningnumber", "errmessage",
        "readstring", "scantokens", "end", "outer", "inner", "write", "to", "readfrom",
        "withprescript", "withpostscript",
        "top", "bot", "lft", "rt", "ulft", "urt", "llft", "lrt",
        --
        "redpart", "greenpart", "bluepart",
        "cyanpart", "magentapart", "yellowpart",
        "blackpart",
        "prescriptpart", "postscriptpart",
        "rgbcolor", "cmykcolor", -- "greycolor", "graycolor",
        "colormodel",  "graypart", "greypart", "greycolor", "graycolor",
        "dashpart", "penpart",
--         "colorpart",
        "stroked", "filled", "textual", "clipped", "bounded", "pathpart",
        "expandafter",
        "minute", "hour",
        "outputformat", "outputtemplate", "filenametemplate", "fontmapfile", "fontmapline",
        "fontpart", "fontsize", "glyph", "restoreclipcolor", "troffmode",
        --
        "runscript", "maketext",
    },
    commands = {
        "upto", "downto",
        "beginfig", "endfig",
        "beginglyph", "endglyph", -- actually a mult-fun one
        "rotatedaround", "reflectedabout",
        "arrowhead",
        "currentpen", "currentpicture", "cuttings",
        "defaultfont", "extra_beginfig", "extra_endfig",
        "down",
        "evenly", "fullcircle", "halfcircle", "identity", "in", "left",
        "pensquare",  "penrazor",  "penspec",
        "origin", "quartercircle", "right",
        "unitsquare", "up", "withdots",
        "abs", "bbox", "ceiling", "center", "cutafter", "cutbefore", "dir",
        "directionpoint", "div", "dotprod", "intersectionpoint", "inverse", "mod",
        "round", "unitvector", "whatever",
        "cutdraw", "draw", "drawarrow", "drawdblarrow", "fill", "filldraw", "drawdot",
        "loggingall", "interact", "tracingall", "tracingnone",
        "pickup",
        "undraw", "unfill", "unfilldraw",
        "buildcycle", "dashpattern", "decr", "dotlabel", "dotlabels", "drawoptions",
        "incr", "label", "labels", "max", "min", "thelabel", "z",
        "beginchar", "blacker", "capsule_end", "change_width",
        "define_blacker_pixels", "define_corrected_pixels",
        "define_good_x_pixels", "define_good_y_pixels",
        "define_horizontal_corrected_pixels", "define_pixels",
        "define_whole_blacker_pixels", "define_whole_pixels",
        "define_whole_vertical_blacker_pixels",
        "define_whole_vertical_pixels", "endchar", "extra_beginchar",
        "extra_endchar", "extra_setup", "font_coding_scheme",
        "clearxy", "clearit", "clearpen", "shipit",
        "font_extra_space",
        "exitunless",
        "relax", "hide", "gobble", "gobbled", "stop",
        "blankpicture",
        "counterclockwise", "tensepath", "takepower", "direction",
        "softjoin", -- "magstep",
        "makelabel", -- "laboff",
        "rotatedabout", "flex", "superellipse", "image",
        "nullpen", "savepen", "clearpen", "penpos", "penlabels", -- "clear_pen_memory",
        "range", "thru",
        "z", "laboff",
        "bye",
        --
        "red", "green", "blue", "cyan", "magenta", "yellow", "black", "white", "background",
        --
        "mm", "pt", "dd", "bp", "cm", "pc", "cc", "in",
        --
        "triplet", "quadruplet",
    },
    internals = { -- we need to remove duplicates above
        --
        "mitered", "rounded", "beveled", "butt", "squared",
        "eps", "epsilon", "infinity",
        "bboxmargin",
        "ahlength", "ahangle",
        "labeloffset", "dotlabeldiam",
        "defaultpen", "defaultscale",
        "join_radius",
        "charscale", -- actually a mult-fun one
        --
        "ditto", "EOF", -- maybe also down etc
        --
        "pen_lft", "pen_rt", "pen_top", "pen_bot", -- "pen_count_",
    },
    metafont = {
         -- :: =: =:| =:|> |=: |=:> |=:| |=:|> |=:|>> ||:
        "autorounding", "beginchar", "blacker", "boundarychar", "capsule_def",
        "capsule_end", "change_width", "chardp", "chardx", "chardy", "charexists",
        "charext", "charht", "charic", "charlist", "charwd", "cull", "cullit",
        "currenttransform", "currentwindow", "define_blacker_pixels",
        "define_corrected_pixels", "define_good_x_pixels", "define_good_y_pixels",
        "define_horizontal_corrected_pixels", "define_pixels",
        "define_whole_blacker_pixels", "define_whole_pixels",
        "define_whole_vertical_blacker_pixels", "define_whole_vertical_pixels",
        "designsize", "display", "displaying", "endchar", "extensible", "extra_beginchar",
        "extra_endchar", "extra_setup", "fillin", "font_coding_scheme",
        "font_extra_space", "font_identifier", "font_normal_shrink",
        "font_normal_space", "font_normal_stretch", "font_quad", "font_size",
        "font_slant", "font_x_height", "fontdimen", "fontmaking", "gfcorners",
        "granularity", "grayfont", "headerbyte", "hppp", "hround", "imagerules",
        "italcorr", "kern", "labelfont", "ligtable", "lowres_fix", "makebox",
        "makegrid", "maketicks", "mode_def", "mode_setup", "nodisplays",
        "notransforms", "numspecial", "o_correction", "openit", "openwindow",
        "pixels_per_inch", "proofing", "proofoffset", "proofrule", "proofrulethickness",
        "rulepen", "screenchars", "screenrule", "screenstrokes", "screen_cols", "screen_rows",
        "showit", "slantfont", "smode", "smoothing", "titlefont", "totalweight",
        "tracingedges", "tracingpens", "turningcheck", "unitpixel", "vppp", "vround",
        "xoffset", "yoffset",
    },
    disabled = {
        "verbatimtex", "troffmode"
    }
}
