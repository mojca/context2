if not modules then modules = { } end modules ['font-agl'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "derived from http://www.adobe.com/devnet/opentype/archives/glyphlist.txt",
    original  = "Adobe Glyph List, version 2.0, September 20, 2002",
}

local allocate      = utilities.storage.allocate

fonts               = fonts or { }
local encodings     = fonts.encodings or { }
fonts.encodings     = encodings
local agl           = fonts.encodings.agl or { }
fonts.encodings.agl = agl

table.setmetatableindex(agl,nil) -- prevent recursive lookups otherwise when autoloaded

local synonyms = {
    Acyrillic                      = 0x0410,
    Becyrillic                     = 0x0411,
    Cdot                           = 0x010A,
    Checyrillic                    = 0x0427,
    Decyrillic                     = 0x0414,
    Djecyrillic                    = 0x0402,
    Dzecyrillic                    = 0x0405,
    Dzhecyrillic                   = 0x040F,
    Ecyrillic                      = 0x0404,
    Edot                           = 0x0116,
    Efcyrillic                     = 0x0424,
    Elcyrillic                     = 0x041B,
    Emcyrillic                     = 0x041C,
    Encyrillic                     = 0x041D,
    Ercyrillic                     = 0x0420,
    Ereversedcyrillic              = 0x042D,
    Escyrillic                     = 0x0421,
    Fitacyrillic                   = 0x0472,
    Gcedilla                       = 0x0122,
    Gdot                           = 0x0120,
    Gecyrillic                     = 0x0413,
    Gheupturncyrillic              = 0x0490,
    Gjecyrillic                    = 0x0403,
    Hardsigncyrillic               = 0x042A,
    IAcyrillic                     = 0x042F,
    IUcyrillic                     = 0x042E,
    Icyrillic                      = 0x0406,
    Idot                           = 0x0130,
    Iecyrillic                     = 0x0415,
    Iicyrillic                     = 0x0418,
    Iishortcyrillic                = 0x0419,
    Iocyrillic                     = 0x0401,
    Izhitsacyrillic                = 0x0474,
    Jecyrillic                     = 0x0408,
    Kacyrillic                     = 0x041A,
    Kcedilla                       = 0x0136,
    Khacyrillic                    = 0x0425,
    Kjecyrillic                    = 0x040C,
    Lcedilla                       = 0x013B,
    Ljecyrillic                    = 0x0409,
    Ncedilla                       = 0x0145,
    Njecyrillic                    = 0x040A,
    Ocyrillic                      = 0x041E,
    Odblacute                      = 0x0150,
    Ohm                            = 0x2126,
    Pecyrillic                     = 0x041F,
    Rcedilla                       = 0x0156,
    Shacyrillic                    = 0x0428,
    Shchacyrillic                  = 0x0429,
    Softsigncyrillic               = 0x042C,
    Tcedilla                       = 0x0162,
    Tecyrillic                     = 0x0422,
    Tsecyrillic                    = 0x0426,
    Tshecyrillic                   = 0x040B,
    Ucyrillic                      = 0x0423,
    Udblacute                      = 0x0170,
    Ushortcyrillic                 = 0x040E,
    Vecyrillic                     = 0x0412,
    Yatcyrillic                    = 0x0462,
    Yericyrillic                   = 0x042B,
    Yicyrillic                     = 0x0407,
    Zdot                           = 0x017B,
    Zecyrillic                     = 0x0417,
    Zhecyrillic                    = 0x0416,
    acutecmb                       = 0x0301,
    acyrillic                      = 0x0430,
    afii00208                      = 0x2015,
    afii08941                      = 0x20A4,
    afii57694                      = 0xFB2A,
    afii57695                      = 0xFB2B,
    afii57700                      = 0xFB4B,
    afii57705                      = 0xFB1F,
    afii57723                      = 0xFB35,
    alef                           = 0x05D0,
    alefmaksurainitialarabic       = 0xFEF3,
    alefmaksuramedialarabic        = 0xFEF4,
    approximatelyequal             = 0x2245,
    asteriskaltonearabic           = 0x066D,
    ayin                           = 0x05E2,
    bet                            = 0x05D1,
    betdagesh                      = 0xFB31,
    blackdownpointingtriangle      = 0x25BC,
    blackleftpointingpointer       = 0x25C4,
    blackrectangle                 = 0x25AC,
    blackrightpointingpointer      = 0x25BA,
    blacksmilingface               = 0x263B,
    blacksquare                    = 0x25A0,
    blackuppointingtriangle        = 0x25B2,
    bulletinverse                  = 0x25D8,
    cdot                           = 0x010B,
    compass                        = 0x263C,
    dagesh                         = 0x05BC,
    dalet                          = 0x05D3,
    daletdagesh                    = 0xFB33,
    dalethatafpatah                = 0x05D3,
    dalethatafpatahhebrew          = 0x05D3,
    dalethatafsegol                = 0x05D3,
    dalethatafsegolhebrew          = 0x05D3,
    dalethebrew                    = 0x05D3,
    dalethiriq                     = 0x05D3,
    dalethiriqhebrew               = 0x05D3,
    daletholam                     = 0x05D3,
    daletholamhebrew               = 0x05D3,
    daletpatah                     = 0x05D3,
    daletpatahhebrew               = 0x05D3,
    daletqamats                    = 0x05D3,
    daletqamatshebrew              = 0x05D3,
    daletqubuts                    = 0x05D3,
    daletqubutshebrew              = 0x05D3,
    daletsegol                     = 0x05D3,
    daletsegolhebrew               = 0x05D3,
    daletsheva                     = 0x05D3,
    daletshevahebrew               = 0x05D3,
    dalettsere                     = 0x05D3,
    dammaarabic                    = 0x064F,
    dammatanaltonearabic           = 0x064C,
    dargahebrew                    = 0x05A7,
    dbllowline                     = 0x2017,
    decimalseparatorarabic         = 0x066B,
    dialytikatonos                 = 0x0385,
    dotbelowcmb                    = 0x0323,
    doubleyodpatah                 = 0xFB1F,
    doubleyodpatahhebrew           = 0xFB1F,
    edot                           = 0x0117,
    eightarabic                    = 0x0668,
    eighthnotebeamed               = 0x266B,
    etnahtafoukhhebrew             = 0x0591,
    etnahtafoukhlefthebrew         = 0x0591,
    etnahtahebrew                  = 0x0591,
    fathaarabic                    = 0x064E,
    finalkaf                       = 0x05DA,
    finalkafdagesh                 = 0xFB3A,
    finalkafhebrew                 = 0x05DA,
    finalkafqamats                 = 0x05DA,
    finalkafqamatshebrew           = 0x05DA,
    finalkafsheva                  = 0x05DA,
    finalmem                       = 0x05DD,
    finalnun                       = 0x05DF,
    finalpe                        = 0x05E3,
    finaltsadi                     = 0x05E5,
    fivearabic                     = 0x0665,
    forall                         = 0x2200,
    fourarabic                     = 0x0664,
    gcedilla                       = 0x0123,
    gdot                           = 0x0121,
    gimel                          = 0x05D2,
    gimeldagesh                    = 0xFB32,
    gravecmb                       = 0x0300,
    haaltonearabic                 = 0x06C1,
    hamzaarabic                    = 0x0621,
    hamzadammaarabic               = 0x0621,
    hamzadammatanarabic            = 0x0621,
    hamzafathaarabic               = 0x0621,
    hamzafathatanarabic            = 0x0621,
    hamzalowarabic                 = 0x0621,
    hamzalowkasraarabic            = 0x0621,
    hamzalowkasratanarabic         = 0x0621,
    hatafpatah                     = 0x05B2,
    hatafpatah16                   = 0x05B2,
    hatafpatah23                   = 0x05B2,
    hatafpatah2f                   = 0x05B2,
    hatafpatahhebrew               = 0x05B2,
    hatafpatahnarrowhebrew         = 0x05B2,
    hatafpatahquarterhebrew        = 0x05B2,
    hatafqamats                    = 0x05B3,
    hatafqamats1b                  = 0x05B3,
    hatafqamats28                  = 0x05B3,
    hatafqamats34                  = 0x05B3,
    hatafqamatshebrew              = 0x05B3,
    hatafqamatsnarrowhebrew        = 0x05B3,
    hatafqamatsquarterhebrew       = 0x05B3,
    hatafsegol                     = 0x05B1,
    hatafsegol17                   = 0x05B1,
    hatafsegol24                   = 0x05B1,
    hatafsegol30                   = 0x05B1,
    hatafsegolhebrew               = 0x05B1,
    hatafsegolnarrowhebrew         = 0x05B1,
    hatafsegolquarterhebrew        = 0x05B1,
    he                             = 0x05D4,
    hedagesh                       = 0xFB34,
    hehfinalalttwoarabic           = 0xFEEA,
    het                            = 0x05D7,
    hiriq                          = 0x05B4,
    hiriq14                        = 0x05B4,
    hiriq21                        = 0x05B4,
    hiriq2d                        = 0x05B4,
    hiriqhebrew                    = 0x05B4,
    hiriqnarrowhebrew              = 0x05B4,
    hiriqquarterhebrew             = 0x05B4,
    holam                          = 0x05B9,
    holam19                        = 0x05B9,
    holam26                        = 0x05B9,
    holam32                        = 0x05B9,
    holamhebrew                    = 0x05B9,
    holamnarrowhebrew              = 0x05B9,
    holamquarterhebrew             = 0x05B9,
    ilde                           = 0x02DC,
    integralbottom                 = 0x2321,
    integraltop                    = 0x2320,
    kaf                            = 0x05DB,
    kafdagesh                      = 0xFB3B,
    kashidaautoarabic              = 0x0640,
    kashidaautonosidebearingarabic = 0x0640,
    kcedilla                       = 0x0137,
    lamed                          = 0x05DC,
    lameddagesh                    = 0xFB3C,
    lamedhebrew                    = 0x05DC,
    lamedholam                     = 0x05DC,
    lamedholamdagesh               = 0x05DC,
    lamedholamdageshhebrew         = 0x05DC,
    laminitialarabic               = 0xFEDF,
    lammeemjeeminitialarabic       = 0xFEDF,
    lcedilla                       = 0x013C,
    logicalnotreversed             = 0x2310,
    mahapakhhebrew                 = 0x05A4,
    mem                            = 0x05DE,
    memdagesh                      = 0xFB3E,
    merkhahebrew                   = 0x05A5,
    merkhakefulahebrew             = 0x05A6,
    middot                         = 0x00B7,
    munahhebrew                    = 0x05A3,
    nbspace                        = 0x00A0,
    ncedilla                       = 0x0146,
    newsheqelsign                  = 0x20AA,
    ninearabic                     = 0x0669,
    noonhehinitialarabic           = 0xFEE7,
    nun                            = 0x05E0,
    nundagesh                      = 0xFB40,
    odblacute                      = 0x0151,
    onearabic                      = 0x0661,
    overscore                      = 0x00AF,
    patah                          = 0x05B7,
    patah11                        = 0x05B7,
    patah1d                        = 0x05B7,
    patah2a                        = 0x05B7,
    patahhebrew                    = 0x05B7,
    patahnarrowhebrew              = 0x05B7,
    patahquarterhebrew             = 0x05B7,
    pe                             = 0x05E4,
    pedagesh                       = 0xFB44,
    qamats                         = 0x05B8,
    qamats10                       = 0x05B8,
    qamats1a                       = 0x05B8,
    qamats1c                       = 0x05B8,
    qamats27                       = 0x05B8,
    qamats29                       = 0x05B8,
    qamats33                       = 0x05B8,
    qamatsde                       = 0x05B8,
    qamatshebrew                   = 0x05B8,
    qamatsnarrowhebrew             = 0x05B8,
    qamatsqatanhebrew              = 0x05B8,
    qamatsqatannarrowhebrew        = 0x05B8,
    qamatsqatanquarterhebrew       = 0x05B8,
    qamatsqatanwidehebrew          = 0x05B8,
    qamatsquarterhebrew            = 0x05B8,
    qof                            = 0x05E7,
    qofdagesh                      = 0xFB47,
    qofhatafpatah                  = 0x05E7,
    qofhatafpatahhebrew            = 0x05E7,
    qofhatafsegol                  = 0x05E7,
    qofhatafsegolhebrew            = 0x05E7,
    qofhebrew                      = 0x05E7,
    qofhiriq                       = 0x05E7,
    qofhiriqhebrew                 = 0x05E7,
    qofholam                       = 0x05E7,
    qofholamhebrew                 = 0x05E7,
    qofpatah                       = 0x05E7,
    qofpatahhebrew                 = 0x05E7,
    qofqamats                      = 0x05E7,
    qofqamatshebrew                = 0x05E7,
    qofqubuts                      = 0x05E7,
    qofqubutshebrew                = 0x05E7,
    qofsegol                       = 0x05E7,
    qofsegolhebrew                 = 0x05E7,
    qofsheva                       = 0x05E7,
    qofshevahebrew                 = 0x05E7,
    qoftsere                       = 0x05E7,
    qubuts                         = 0x05BB,
    qubuts18                       = 0x05BB,
    qubuts25                       = 0x05BB,
    qubuts31                       = 0x05BB,
    qubutshebrew                   = 0x05BB,
    qubutsnarrowhebrew             = 0x05BB,
    qubutsquarterhebrew            = 0x05BB,
    quoteleftreversed              = 0x201B,
    rafe                           = 0x05BF,
    rcedilla                       = 0x0157,
    reharabic                      = 0x0631,
    resh                           = 0x05E8,
    reshhatafpatah                 = 0x05E8,
    reshhatafpatahhebrew           = 0x05E8,
    reshhatafsegol                 = 0x05E8,
    reshhatafsegolhebrew           = 0x05E8,
    reshhebrew                     = 0x05E8,
    reshhiriq                      = 0x05E8,
    reshhiriqhebrew                = 0x05E8,
    reshholam                      = 0x05E8,
    reshholamhebrew                = 0x05E8,
    reshpatah                      = 0x05E8,
    reshpatahhebrew                = 0x05E8,
    reshqamats                     = 0x05E8,
    reshqamatshebrew               = 0x05E8,
    reshqubuts                     = 0x05E8,
    reshqubutshebrew               = 0x05E8,
    reshsegol                      = 0x05E8,
    reshsegolhebrew                = 0x05E8,
    reshsheva                      = 0x05E8,
    reshshevahebrew                = 0x05E8,
    reshtsere                      = 0x05E8,
    reviahebrew                    = 0x0597,
    samekh                         = 0x05E1,
    samekhdagesh                   = 0xFB41,
    segol                          = 0x05B6,
    segol13                        = 0x05B6,
    segol1f                        = 0x05B6,
    segol2c                        = 0x05B6,
    segolhebrew                    = 0x05B6,
    segolnarrowhebrew              = 0x05B6,
    segolquarterhebrew             = 0x05B6,
    sevenarabic                    = 0x0667,
    sfthyphen                      = 0x00AD,
    shaddaarabic                   = 0x0651,
    sheqel                         = 0x20AA,
    sheva                          = 0x05B0,
    sheva115                       = 0x05B0,
    sheva15                        = 0x05B0,
    sheva22                        = 0x05B0,
    sheva2e                        = 0x05B0,
    shevahebrew                    = 0x05B0,
    shevanarrowhebrew              = 0x05B0,
    shevaquarterhebrew             = 0x05B0,
    shin                           = 0x05E9,
    shindagesh                     = 0xFB49,
    shindageshshindot              = 0xFB2C,
    shindageshsindot               = 0xFB2D,
    shinshindot                    = 0xFB2A,
    shinsindot                     = 0xFB2B,
    siluqhebrew                    = 0x05BD,
    sixarabic                      = 0x0666,
    tav                            = 0x05EA,
    tavdages                       = 0xFB4A,
    tavdagesh                      = 0xFB4A,
    tcedilla                       = 0x0163,
    tchehinitialarabic             = 0xFB7C,
    tet                            = 0x05D8,
    tetdagesh                      = 0xFB38,
    tevirhebrew                    = 0x059B,
    thousandsseparatorarabic       = 0x066C,
    threearabic                    = 0x0663,
    tildecmb                       = 0x0303,
    tipehahebrew                   = 0x0596,
    tsadi                          = 0x05E6,
    tsadidagesh                    = 0xFB46,
    tsere                          = 0x05B5,
    tsere12                        = 0x05B5,
    tsere1e                        = 0x05B5,
    tsere2b                        = 0x05B5,
    tserehebrew                    = 0x05B5,
    tserenarrowhebrew              = 0x05B5,
    tserequarterhebrew             = 0x05B5,
    twoarabic                      = 0x0662,
    udblacute                      = 0x0171,
    vav                            = 0x05D5,
    vavdagesh                      = 0xFB35,
    vavdagesh65                    = 0xFB35,
    vavholam                       = 0xFB4B,
    yerahbenyomohebrew             = 0x05AA,
    yod                            = 0x05D9,
    yoddagesh                      = 0xFB39,
    zayin                          = 0x05D6,
    zayindagesh                    = 0xFB36,
    zdot                           = 0x017C,
    zeroarabic                     = 0x0660,
}

local extras   = allocate { -- private extensions
    Dcroat          = 0x0110,
    Delta           = 0x2206,
    Euro            = 0x20AC,
    H18533          = 0x25CF,
    H18543          = 0x25AA,
    H18551          = 0x25AB,
    H22073          = 0x25A1,
    Ldot            = 0x013F,
    Oslashacute     = 0x01FE,
    SF10000         = 0x250C,
    SF20000         = 0x2514,
    SF30000         = 0x2510,
    SF40000         = 0x2518,
    SF50000         = 0x253C,
    SF60000         = 0x252C,
    SF70000         = 0x2534,
    SF80000         = 0x251C,
    SF90000         = 0x2524,
    Upsilon1        = 0x03D2,
    afii10066       = 0x0431,
    afii10067       = 0x0432,
    afii10068       = 0x0433,
    afii10069       = 0x0434,
    afii10070       = 0x0435,
    afii10071       = 0x0451,
    afii10072       = 0x0436,
    afii10073       = 0x0437,
    afii10074       = 0x0438,
    afii10075       = 0x0439,
    afii10076       = 0x043A,
    afii10077       = 0x043B,
    afii10078       = 0x043C,
    afii10079       = 0x043D,
    afii10080       = 0x043E,
    afii10081       = 0x043F,
    afii10082       = 0x0440,
    afii10083       = 0x0441,
    afii10084       = 0x0442,
    afii10085       = 0x0443,
    afii10086       = 0x0444,
    afii10087       = 0x0445,
    afii10088       = 0x0446,
    afii10089       = 0x0447,
    afii10090       = 0x0448,
    afii10091       = 0x0449,
    afii10092       = 0x044A,
    afii10093       = 0x044B,
    afii10094       = 0x044C,
    afii10095       = 0x044D,
    afii10096       = 0x044E,
    afii10097       = 0x044F,
    afii10098       = 0x0491,
    afii10099       = 0x0452,
    afii10100       = 0x0453,
    afii10101       = 0x0454,
    afii10102       = 0x0455,
    afii10103       = 0x0456,
    afii10104       = 0x0457,
    afii10105       = 0x0458,
    afii10106       = 0x0459,
    afii10107       = 0x045A,
    afii10108       = 0x045B,
    afii10109       = 0x045C,
    afii10110       = 0x045E,
    afii10193       = 0x045F,
    afii10194       = 0x0463,
    afii10195       = 0x0473,
    afii10196       = 0x0475,
    afii10846       = 0x04D9,
    afii208         = 0x2015,
    afii57381       = 0x066A,
    afii57388       = 0x060C,
    afii57392       = 0x0660,
    afii57393       = 0x0661,
    afii57394       = 0x0662,
    afii57395       = 0x0663,
    afii57396       = 0x0664,
    afii57397       = 0x0665,
    afii57398       = 0x0666,
    afii57399       = 0x0667,
    afii57400       = 0x0668,
    afii57401       = 0x0669,
    afii57403       = 0x061B,
    afii57407       = 0x061F,
    afii57409       = 0x0621,
    afii57410       = 0x0622,
    afii57411       = 0x0623,
    afii57412       = 0x0624,
    afii57413       = 0x0625,
    afii57414       = 0x0626,
    afii57415       = 0x0627,
    afii57416       = 0x0628,
    afii57417       = 0x0629,
    afii57418       = 0x062A,
    afii57419       = 0x062B,
    afii57420       = 0x062C,
    afii57421       = 0x062D,
    afii57422       = 0x062E,
    afii57423       = 0x062F,
    afii57424       = 0x0630,
    afii57425       = 0x0631,
    afii57426       = 0x0632,
    afii57427       = 0x0633,
    afii57428       = 0x0634,
    afii57429       = 0x0635,
    afii57430       = 0x0636,
    afii57431       = 0x0637,
    afii57432       = 0x0638,
    afii57433       = 0x0639,
    afii57434       = 0x063A,
    afii57440       = 0x0640,
    afii57441       = 0x0641,
    afii57442       = 0x0642,
    afii57443       = 0x0643,
    afii57444       = 0x0644,
    afii57445       = 0x0645,
    afii57446       = 0x0646,
    afii57448       = 0x0648,
    afii57449       = 0x0649,
    afii57450       = 0x064A,
    afii57451       = 0x064B,
    afii57452       = 0x064C,
    afii57453       = 0x064D,
    afii57454       = 0x064E,
    afii57455       = 0x064F,
    afii57456       = 0x0650,
    afii57457       = 0x0651,
    afii57458       = 0x0652,
    afii57470       = 0x0647,
    afii57505       = 0x06A4,
    afii57506       = 0x067E,
    afii57507       = 0x0686,
    afii57508       = 0x0698,
    afii57509       = 0x06AF,
    afii57511       = 0x0679,
    afii57512       = 0x0688,
    afii57513       = 0x0691,
    afii57514       = 0x06BA,
    afii57519       = 0x06D2,
    afii57636       = 0x20AA,
    afii57645       = 0x05BE,
    afii57658       = 0x05C3,
    afii57664       = 0x05D0,
    afii57665       = 0x05D1,
    afii57666       = 0x05D2,
    afii57667       = 0x05D3,
    afii57668       = 0x05D4,
    afii57669       = 0x05D5,
    afii57670       = 0x05D6,
    afii57671       = 0x05D7,
    afii57672       = 0x05D8,
    afii57673       = 0x05D9,
    afii57674       = 0x05DA,
    afii57675       = 0x05DB,
    afii57676       = 0x05DC,
    afii57677       = 0x05DD,
    afii57678       = 0x05DE,
    afii57679       = 0x05DF,
    afii57680       = 0x05E0,
    afii57681       = 0x05E1,
    afii57682       = 0x05E2,
    afii57683       = 0x05E3,
    afii57684       = 0x05E4,
    afii57685       = 0x05E5,
    afii57686       = 0x05E6,
    afii57687       = 0x05E7,
    afii57688       = 0x05E8,
    afii57689       = 0x05E9,
    afii57690       = 0x05EA,
    afii57716       = 0x05F0,
    afii57717       = 0x05F1,
    afii57718       = 0x05F2,
    afii57793       = 0x05B4,
    afii57794       = 0x05B5,
    afii57795       = 0x05B6,
    afii57796       = 0x05BB,
    afii57797       = 0x05B8,
    afii57798       = 0x05B7,
    afii57799       = 0x05B0,
    afii57800       = 0x05B2,
    afii57801       = 0x05B1,
    afii57802       = 0x05B3,
    afii57803       = 0x05C2,
    afii57804       = 0x05C1,
    afii57806       = 0x05B9,
    afii57807       = 0x05BC,
    afii57839       = 0x05BD,
    afii57841       = 0x05BF,
    afii57842       = 0x05C0,
    afii57929       = 0x02BC,
    afii61248       = 0x2105,
    afii61289       = 0x2113,
    afii61352       = 0x2116,
    afii61664       = 0x200C,
    afii63167       = 0x066D,
    afii64937       = 0x02BD,
    arrowdblboth    = 0x21D4,
    arrowdblleft    = 0x21D0,
    arrowdblright   = 0x21D2,
    arrowupdnbse    = 0x21A8,
    bar             = 0x007C,
    circle          = 0x25CB,
    circlemultiply  = 0x2297,
    circleplus      = 0x2295,
    club            = 0x2663,
    colonmonetary   = 0x20A1,
    dcroat          = 0x0111,
    dkshade         = 0x2593,
    existential     = 0x2203,
    female          = 0x2640,
    gradient        = 0x2207,
    heart           = 0x2665,
    hookabovecomb   = 0x0309,
    invcircle       = 0x25D9,
    ldot            = 0x0140,
    longs           = 0x017F,
    ltshade         = 0x2591,
    male            = 0x2642,
    mu              = 0x00B5,
    napostrophe     = 0x0149,
    notelement      = 0x2209,
    omega1          = 0x03D6,
    openbullet      = 0x25E6,
    orthogonal      = 0x221F,
    oslashacute     = 0x01FF,
    phi1            = 0x03D5,
    propersubset    = 0x2282,
    propersuperset  = 0x2283,
    reflexsubset    = 0x2286,
    reflexsuperset  = 0x2287,
    shade           = 0x2592,
    sigma1          = 0x03C2,
    similar         = 0x223C,
    smileface       = 0x263A,
    spacehackarabic = 0x0020,
    spade           = 0x2660,
    theta1          = 0x03D1,
    twodotenleader  = 0x2025,
}

-- We load this table only when needed. We could use a loading mechanism
-- return the table but there are no more vectors like this so why bother.
--
-- Well, we currently have this table preloaded anyway.

local names    = agl.names
local unicodes = agl.unicodes
local ctxcodes = agl.ctxcodes

if not names then

    names    = allocate { } -- filled from char-def.lua
    unicodes = allocate { }
    ctxcodes = allocate { }

    for u, c in next, characters.data do
        local a = c.adobename
        if a then
            unicodes[a] = u
            names   [u] = a
        end
        local n = c.contextname
        if n then
            ctxcodes[n] = u
         -- names   [u] = a
        end
    end

    for a, u in next, extras do
        unicodes[a] = u
        if not names[u] then
            names[u] = a
        end
    end

    for s, u in next, synonyms do
        unicodes[s] = u
        if not names[u] then
            names[u] = s
        end
    end

    if storage then
        storage.register("encodings/names",    names,    "fonts.encodings.names")
        storage.register("encodings/unicodes", unicodes, "fonts.encodings.unicodes")
        storage.register("encodings/ctxcodes", ctxcodes, "fonts.encodings.ctxcodes")
    end

end

agl.names    = names     -- unicode -> name
agl.unicodes = unicodes  -- name -> unicode
agl.ctxcodes = ctxcodes  -- name -> unicode
agl.synonyms = synonyms  -- merged into the other two
agl.extras   = extras    -- merged into the other two

return agl
