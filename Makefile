# This Makefile is for the LaTeXML extension to perl.
#
# It was generated automatically by MakeMaker version
# 6.17 (Revision: 1.133) from the contents of
# Makefile.PL. Don't edit this file, edit Makefile.PL instead.
#
#       ANY CHANGES MADE HERE WILL BE LOST!
#
#   MakeMaker ARGV: (q[DLMF])
#
#   MakeMaker Parameters:

#     AUTHOR => q[Bruce Miller <bruce.miller@nist.gov>]
#     EXE_FILES => [q[bin/latexml], q[bin/latexmlpost], q[bin/latexmlfind], q[bin/dlmfpost]]
#     NAME => q[LaTeXML]
#     PREREQ_PM => { XML::LibXML::XPathContext=>q[0], XML::LibXSLT=>q[1.57], XML::LibXML=>q[1.57], Image::Magick=>q[0], Parse::RecDescent=>q[0] }
#     VERSION_FROM => q[lib/LaTeXML.pm]

# --- MakeMaker post_initialize section:


# --- MakeMaker const_config section:

# These definitions are from config.sh (via /usr/lib/perl5/5.8.6/i386-linux-thread-multi/Config.pm)

# They may have been overridden via Makefile.PL or on the command line
AR = ar
CC = gcc
CCCDLFLAGS = -fPIC
CCDLFLAGS = -Wl,-E -Wl,-rpath,/usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE
DLEXT = so
DLSRC = dl_dlopen.xs
LD = gcc
LDDLFLAGS = -shared -L/usr/local/lib
LDFLAGS =  -L/usr/local/lib
LIBC = /lib/libc-2.3.5.so
LIB_EXT = .a
OBJ_EXT = .o
OSNAME = linux
OSVERS = 2.6.9-22.18.bz155725.elsmp
RANLIB = :
SITELIBEXP = /usr/lib/perl5/site_perl/5.8.6
SITEARCHEXP = /usr/lib/perl5/site_perl/5.8.6/i386-linux-thread-multi
SO = so
EXE_EXT = 
FULL_AR = /usr/bin/ar
VENDORARCHEXP = /usr/lib/perl5/vendor_perl/5.8.6/i386-linux-thread-multi
VENDORLIBEXP = /usr/lib/perl5/vendor_perl/5.8.6


# --- MakeMaker constants section:
AR_STATIC_ARGS = cr
DIRFILESEP = /
NAME = LaTeXML
NAME_SYM = LaTeXML
VERSION = 0.4.1
VERSION_MACRO = VERSION
VERSION_SYM = 0_4_1
DEFINE_VERSION = -D$(VERSION_MACRO)=\"$(VERSION)\"
XS_VERSION = 0.4.1
XS_VERSION_MACRO = XS_VERSION
XS_DEFINE_VERSION = -D$(XS_VERSION_MACRO)=\"$(XS_VERSION)\"
INST_ARCHLIB = blib/arch
INST_SCRIPT = blib/script
INST_BIN = blib/bin
INST_LIB = blib/lib
INST_MAN1DIR = blib/man1
INST_MAN3DIR = blib/man3
MAN1EXT = 1
MAN3EXT = 3pm
INSTALLDIRS = site
DESTDIR = 
PREFIX = 
PERLPREFIX = /usr
SITEPREFIX = /usr
VENDORPREFIX = /usr
INSTALLPRIVLIB = $(PERLPREFIX)/lib/perl5/5.8.6
DESTINSTALLPRIVLIB = $(DESTDIR)$(INSTALLPRIVLIB)
INSTALLSITELIB = $(SITEPREFIX)/lib/perl5/site_perl/5.8.6
DESTINSTALLSITELIB = $(DESTDIR)$(INSTALLSITELIB)
INSTALLVENDORLIB = $(VENDORPREFIX)/lib/perl5/vendor_perl/5.8.6
DESTINSTALLVENDORLIB = $(DESTDIR)$(INSTALLVENDORLIB)
INSTALLARCHLIB = $(PERLPREFIX)/lib/perl5/5.8.6/i386-linux-thread-multi
DESTINSTALLARCHLIB = $(DESTDIR)$(INSTALLARCHLIB)
INSTALLSITEARCH = $(SITEPREFIX)/lib/perl5/site_perl/5.8.6/i386-linux-thread-multi
DESTINSTALLSITEARCH = $(DESTDIR)$(INSTALLSITEARCH)
INSTALLVENDORARCH = $(VENDORPREFIX)/lib/perl5/vendor_perl/5.8.6/i386-linux-thread-multi
DESTINSTALLVENDORARCH = $(DESTDIR)$(INSTALLVENDORARCH)
INSTALLBIN = $(PERLPREFIX)/bin
DESTINSTALLBIN = $(DESTDIR)$(INSTALLBIN)
INSTALLSITEBIN = $(SITEPREFIX)/bin
DESTINSTALLSITEBIN = $(DESTDIR)$(INSTALLSITEBIN)
INSTALLVENDORBIN = $(VENDORPREFIX)/bin
DESTINSTALLVENDORBIN = $(DESTDIR)$(INSTALLVENDORBIN)
INSTALLSCRIPT = $(PERLPREFIX)/bin
DESTINSTALLSCRIPT = $(DESTDIR)$(INSTALLSCRIPT)
INSTALLMAN1DIR = $(PERLPREFIX)/share/man/man1
DESTINSTALLMAN1DIR = $(DESTDIR)$(INSTALLMAN1DIR)
INSTALLSITEMAN1DIR = $(SITEPREFIX)/share/man/man1
DESTINSTALLSITEMAN1DIR = $(DESTDIR)$(INSTALLSITEMAN1DIR)
INSTALLVENDORMAN1DIR = $(VENDORPREFIX)/share/man/man1
DESTINSTALLVENDORMAN1DIR = $(DESTDIR)$(INSTALLVENDORMAN1DIR)
INSTALLMAN3DIR = $(PERLPREFIX)/share/man/man3
DESTINSTALLMAN3DIR = $(DESTDIR)$(INSTALLMAN3DIR)
INSTALLSITEMAN3DIR = $(SITEPREFIX)/share/man/man3
DESTINSTALLSITEMAN3DIR = $(DESTDIR)$(INSTALLSITEMAN3DIR)
INSTALLVENDORMAN3DIR = $(VENDORPREFIX)/share/man/man3
DESTINSTALLVENDORMAN3DIR = $(DESTDIR)$(INSTALLVENDORMAN3DIR)
PERL_LIB = /usr/lib/perl5/5.8.6
PERL_ARCHLIB = /usr/lib/perl5/5.8.6/i386-linux-thread-multi
LIBPERL_A = libperl.a
FIRST_MAKEFILE = Makefile
MAKEFILE_OLD = $(FIRST_MAKEFILE).old
MAKE_APERL_FILE = $(FIRST_MAKEFILE).aperl
PERLMAINCC = $(CC)
PERL_INC = /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE
PERL = /usr/bin/perl
FULLPERL = /usr/bin/perl
ABSPERL = $(PERL)
PERLRUN = $(PERL)
FULLPERLRUN = $(FULLPERL)
ABSPERLRUN = $(ABSPERL)
PERLRUNINST = $(PERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
FULLPERLRUNINST = $(FULLPERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
ABSPERLRUNINST = $(ABSPERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
PERL_CORE = 0
PERM_RW = 644
PERM_RWX = 755

MAKEMAKER   = /usr/lib/perl5/5.8.6/ExtUtils/MakeMaker.pm
MM_VERSION  = 6.17
MM_REVISION = 1.133

# FULLEXT = Pathname for extension directory (eg Foo/Bar/Oracle).
# BASEEXT = Basename part of FULLEXT. May be just equal FULLEXT. (eg Oracle)
# PARENT_NAME = NAME without BASEEXT and no trailing :: (eg Foo::Bar)
# DLBASE  = Basename part of dynamic library. May be just equal BASEEXT.
FULLEXT = LaTeXML
BASEEXT = LaTeXML
PARENT_NAME = 
DLBASE = $(BASEEXT)
VERSION_FROM = lib/LaTeXML.pm
OBJECT = 
LDFROM = $(OBJECT)
LINKTYPE = dynamic

# Handy lists of source code files:
XS_FILES = 
C_FILES  = 
O_FILES  = 
H_FILES  = 
MAN1PODS = bin/latexml \
	bin/latexmlfind \
	bin/latexmlpost
MAN3PODS = lib/LaTeXML.pm \
	lib/LaTeXML/Box.pm \
	lib/LaTeXML/Definition.pm \
	lib/LaTeXML/Document.pm \
	lib/LaTeXML/Error.pm \
	lib/LaTeXML/Font.pm \
	lib/LaTeXML/Global.pm \
	lib/LaTeXML/Gullet.pm \
	lib/LaTeXML/MathParser.pm \
	lib/LaTeXML/Model.pm \
	lib/LaTeXML/Mouth.pm \
	lib/LaTeXML/Number.pm \
	lib/LaTeXML/Object.pm \
	lib/LaTeXML/Package.pm \
	lib/LaTeXML/Parameters.pm \
	lib/LaTeXML/Post.pm \
	lib/LaTeXML/Rewrite.pm \
	lib/LaTeXML/State.pm \
	lib/LaTeXML/Stomach.pm \
	lib/LaTeXML/Token.pm

# Where is the Config information that we are using/depend on
CONFIGDEP = $(PERL_ARCHLIB)$(DIRFILESEP)Config.pm $(PERL_INC)$(DIRFILESEP)config.h

# Where to build things
INST_LIBDIR      = $(INST_LIB)
INST_ARCHLIBDIR  = $(INST_ARCHLIB)

INST_AUTODIR     = $(INST_LIB)/auto/$(FULLEXT)
INST_ARCHAUTODIR = $(INST_ARCHLIB)/auto/$(FULLEXT)

INST_STATIC      = 
INST_DYNAMIC     = 
INST_BOOT        = 

# Extra linker info
EXPORT_LIST        = 
PERL_ARCHIVE       = 
PERL_ARCHIVE_AFTER = 


TO_INST_PM = lib/LaTeXML.pm \
	lib/LaTeXML/Box.pm \
	lib/LaTeXML/Definition.pm \
	lib/LaTeXML/Document.pm \
	lib/LaTeXML/Error.pm \
	lib/LaTeXML/Font.pm \
	lib/LaTeXML/Global.pm \
	lib/LaTeXML/Gullet.pm \
	lib/LaTeXML/MathGrammar \
	lib/LaTeXML/MathParser.pm \
	lib/LaTeXML/Model.pm \
	lib/LaTeXML/Mouth.pm \
	lib/LaTeXML/Number.pm \
	lib/LaTeXML/Object.pm \
	lib/LaTeXML/Package.pm \
	lib/LaTeXML/Package/DLMF.ltxml \
	lib/LaTeXML/Package/DLMFbib.ltxml \
	lib/LaTeXML/Package/DLMFmath.ltxml \
	lib/LaTeXML/Package/LaTeX.ltxml \
	lib/LaTeXML/Package/TeX.ltxml \
	lib/LaTeXML/Package/acronym.ltxml \
	lib/LaTeXML/Package/ae.ltxml \
	lib/LaTeXML/Package/alltt.ltxml \
	lib/LaTeXML/Package/amsbsy.ltxml \
	lib/LaTeXML/Package/amsfonts.ltxml \
	lib/LaTeXML/Package/amsmath.ltxml \
	lib/LaTeXML/Package/amsopn.ltxml \
	lib/LaTeXML/Package/amsrefs.ltxml \
	lib/LaTeXML/Package/amssymb.ltxml \
	lib/LaTeXML/Package/amstext.ltxml \
	lib/LaTeXML/Package/amsxtra.ltxml \
	lib/LaTeXML/Package/article.ltxml \
	lib/LaTeXML/Package/color.ltxml \
	lib/LaTeXML/Package/comment.ltxml \
	lib/LaTeXML/Package/eucal.ltxml \
	lib/LaTeXML/Package/eufrak.ltxml \
	lib/LaTeXML/Package/euscript.ltxml \
	lib/LaTeXML/Package/graphics.ltxml \
	lib/LaTeXML/Package/graphicx.ltxml \
	lib/LaTeXML/Package/html.ltxml \
	lib/LaTeXML/Package/hyperref.ltxml \
	lib/LaTeXML/Package/keyval.ltxml \
	lib/LaTeXML/Package/latexml.ltxml \
	lib/LaTeXML/Package/makeidx.ltxml \
	lib/LaTeXML/Package/mcsd.ltxml \
	lib/LaTeXML/Package/pspicture.ltxml \
	lib/LaTeXML/Package/pst-node.ltxml \
	lib/LaTeXML/Package/pstricks.ltxml \
	lib/LaTeXML/Package/url.ltxml \
	lib/LaTeXML/Parameters.pm \
	lib/LaTeXML/Post.pm \
	lib/LaTeXML/Post/Graphics.pm \
	lib/LaTeXML/Post/MathImages.pm \
	lib/LaTeXML/Post/MathML.pm \
	lib/LaTeXML/Post/MathML.pm.save \
	lib/LaTeXML/Post/OpenMath.pm \
	lib/LaTeXML/Post/PurgeXMath.pm \
	lib/LaTeXML/Post/SVG.pm \
	lib/LaTeXML/Post/XSLT.pm \
	lib/LaTeXML/Rewrite.pm \
	lib/LaTeXML/State.pm \
	lib/LaTeXML/Stomach.pm \
	lib/LaTeXML/Token.pm \
	lib/LaTeXML/Util/Color.pm \
	lib/LaTeXML/Util/Geometry.pm \
	lib/LaTeXML/Util/LibXML.pm \
	lib/LaTeXML/Util/Pathname.pm \
	lib/LaTeXML/Util/Transform.pm \
	lib/LaTeXML/dtd/DLMF.dtd \
	lib/LaTeXML/dtd/LaTeXML-MathML-OpenMath.dtd \
	lib/LaTeXML/dtd/LaTeXML-MathML.dtd \
	lib/LaTeXML/dtd/LaTeXML.css \
	lib/LaTeXML/dtd/LaTeXML.dtd \
	lib/LaTeXML/dtd/catalog \
	lib/LaTeXML/dtd/core.xsl.tail \
	lib/LaTeXML/dtd/html.xsl.head \
	lib/LaTeXML/dtd/xhtml.xsl.head

PM_TO_BLIB = lib/LaTeXML/Package/amsmath.ltxml \
	blib/lib/LaTeXML/Package/amsmath.ltxml \
	lib/LaTeXML/Util/Color.pm \
	blib/lib/LaTeXML/Util/Color.pm \
	lib/LaTeXML/Model.pm \
	blib/lib/LaTeXML/Model.pm \
	lib/LaTeXML/Package/eufrak.ltxml \
	blib/lib/LaTeXML/Package/eufrak.ltxml \
	lib/LaTeXML/MathGrammar \
	blib/lib/LaTeXML/MathGrammar \
	lib/LaTeXML/Definition.pm \
	blib/lib/LaTeXML/Definition.pm \
	lib/LaTeXML/Post/MathImages.pm \
	blib/lib/LaTeXML/Post/MathImages.pm \
	lib/LaTeXML/Package/graphicx.ltxml \
	blib/lib/LaTeXML/Package/graphicx.ltxml \
	lib/LaTeXML/Package/LaTeX.ltxml \
	blib/lib/LaTeXML/Package/LaTeX.ltxml \
	lib/LaTeXML/State.pm \
	blib/lib/LaTeXML/State.pm \
	lib/LaTeXML/Token.pm \
	blib/lib/LaTeXML/Token.pm \
	lib/LaTeXML/dtd/core.xsl.tail \
	blib/lib/LaTeXML/dtd/core.xsl.tail \
	lib/LaTeXML/Package/amstext.ltxml \
	blib/lib/LaTeXML/Package/amstext.ltxml \
	lib/LaTeXML/Package/amsbsy.ltxml \
	blib/lib/LaTeXML/Package/amsbsy.ltxml \
	lib/LaTeXML/Package/makeidx.ltxml \
	blib/lib/LaTeXML/Package/makeidx.ltxml \
	lib/LaTeXML/dtd/DLMF.dtd \
	blib/lib/LaTeXML/dtd/DLMF.dtd \
	lib/LaTeXML/Post/OpenMath.pm \
	blib/lib/LaTeXML/Post/OpenMath.pm \
	lib/LaTeXML/Package/amssymb.ltxml \
	blib/lib/LaTeXML/Package/amssymb.ltxml \
	lib/LaTeXML/dtd/catalog \
	blib/lib/LaTeXML/dtd/catalog \
	lib/LaTeXML/Package/amsxtra.ltxml \
	blib/lib/LaTeXML/Package/amsxtra.ltxml \
	lib/LaTeXML/Post/MathML.pm \
	blib/lib/LaTeXML/Post/MathML.pm \
	lib/LaTeXML/Package/ae.ltxml \
	blib/lib/LaTeXML/Package/ae.ltxml \
	lib/LaTeXML/Package/euscript.ltxml \
	blib/lib/LaTeXML/Package/euscript.ltxml \
	lib/LaTeXML/Package/pspicture.ltxml \
	blib/lib/LaTeXML/Package/pspicture.ltxml \
	lib/LaTeXML/Package/article.ltxml \
	blib/lib/LaTeXML/Package/article.ltxml \
	lib/LaTeXML/Package/amsfonts.ltxml \
	blib/lib/LaTeXML/Package/amsfonts.ltxml \
	lib/LaTeXML/Font.pm \
	blib/lib/LaTeXML/Font.pm \
	lib/LaTeXML/Post/XSLT.pm \
	blib/lib/LaTeXML/Post/XSLT.pm \
	lib/LaTeXML/Rewrite.pm \
	blib/lib/LaTeXML/Rewrite.pm \
	lib/LaTeXML/dtd/xhtml.xsl.head \
	blib/lib/LaTeXML/dtd/xhtml.xsl.head \
	lib/LaTeXML/Gullet.pm \
	blib/lib/LaTeXML/Gullet.pm \
	lib/LaTeXML/Package/hyperref.ltxml \
	blib/lib/LaTeXML/Package/hyperref.ltxml \
	lib/LaTeXML/Error.pm \
	blib/lib/LaTeXML/Error.pm \
	lib/LaTeXML/Package/DLMFbib.ltxml \
	blib/lib/LaTeXML/Package/DLMFbib.ltxml \
	lib/LaTeXML/Util/Transform.pm \
	blib/lib/LaTeXML/Util/Transform.pm \
	lib/LaTeXML/Post/MathML.pm.save \
	blib/lib/LaTeXML/Post/MathML.pm.save \
	lib/LaTeXML/Package/pst-node.ltxml \
	blib/lib/LaTeXML/Package/pst-node.ltxml \
	lib/LaTeXML/Box.pm \
	blib/lib/LaTeXML/Box.pm \
	lib/LaTeXML/Post.pm \
	blib/lib/LaTeXML/Post.pm \
	lib/LaTeXML/Package/DLMF.ltxml \
	blib/lib/LaTeXML/Package/DLMF.ltxml \
	lib/LaTeXML/Post/SVG.pm \
	blib/lib/LaTeXML/Post/SVG.pm \
	lib/LaTeXML/Document.pm \
	blib/lib/LaTeXML/Document.pm \
	lib/LaTeXML/dtd/LaTeXML.dtd \
	blib/lib/LaTeXML/dtd/LaTeXML.dtd \
	lib/LaTeXML/Package/keyval.ltxml \
	blib/lib/LaTeXML/Package/keyval.ltxml \
	lib/LaTeXML/Util/Geometry.pm \
	blib/lib/LaTeXML/Util/Geometry.pm \
	lib/LaTeXML/Package/comment.ltxml \
	blib/lib/LaTeXML/Package/comment.ltxml \
	lib/LaTeXML/Package/latexml.ltxml \
	blib/lib/LaTeXML/Package/latexml.ltxml \
	lib/LaTeXML/MathParser.pm \
	blib/lib/LaTeXML/MathParser.pm \
	lib/LaTeXML/Mouth.pm \
	blib/lib/LaTeXML/Mouth.pm \
	lib/LaTeXML/Package/acronym.ltxml \
	blib/lib/LaTeXML/Package/acronym.ltxml \
	lib/LaTeXML/Post/PurgeXMath.pm \
	blib/lib/LaTeXML/Post/PurgeXMath.pm \
	lib/LaTeXML/Package.pm \
	blib/lib/LaTeXML/Package.pm \
	lib/LaTeXML/Package/alltt.ltxml \
	blib/lib/LaTeXML/Package/alltt.ltxml \
	lib/LaTeXML/Global.pm \
	blib/lib/LaTeXML/Global.pm \
	lib/LaTeXML/Util/Pathname.pm \
	blib/lib/LaTeXML/Util/Pathname.pm \
	lib/LaTeXML/Object.pm \
	blib/lib/LaTeXML/Object.pm \
	lib/LaTeXML/Package/pstricks.ltxml \
	blib/lib/LaTeXML/Package/pstricks.ltxml \
	lib/LaTeXML/Package/amsrefs.ltxml \
	blib/lib/LaTeXML/Package/amsrefs.ltxml \
	lib/LaTeXML/dtd/LaTeXML.css \
	blib/lib/LaTeXML/dtd/LaTeXML.css \
	lib/LaTeXML/dtd/html.xsl.head \
	blib/lib/LaTeXML/dtd/html.xsl.head \
	lib/LaTeXML/dtd/LaTeXML-MathML.dtd \
	blib/lib/LaTeXML/dtd/LaTeXML-MathML.dtd \
	lib/LaTeXML/Parameters.pm \
	blib/lib/LaTeXML/Parameters.pm \
	lib/LaTeXML/Util/LibXML.pm \
	blib/lib/LaTeXML/Util/LibXML.pm \
	lib/LaTeXML/Package/color.ltxml \
	blib/lib/LaTeXML/Package/color.ltxml \
	lib/LaTeXML/Package/amsopn.ltxml \
	blib/lib/LaTeXML/Package/amsopn.ltxml \
	lib/LaTeXML/Stomach.pm \
	blib/lib/LaTeXML/Stomach.pm \
	lib/LaTeXML/Package/eucal.ltxml \
	blib/lib/LaTeXML/Package/eucal.ltxml \
	lib/LaTeXML/Package/TeX.ltxml \
	blib/lib/LaTeXML/Package/TeX.ltxml \
	lib/LaTeXML/Package/DLMFmath.ltxml \
	blib/lib/LaTeXML/Package/DLMFmath.ltxml \
	lib/LaTeXML/dtd/LaTeXML-MathML-OpenMath.dtd \
	blib/lib/LaTeXML/dtd/LaTeXML-MathML-OpenMath.dtd \
	lib/LaTeXML/Number.pm \
	blib/lib/LaTeXML/Number.pm \
	lib/LaTeXML/Package/graphics.ltxml \
	blib/lib/LaTeXML/Package/graphics.ltxml \
	lib/LaTeXML/Package/html.ltxml \
	blib/lib/LaTeXML/Package/html.ltxml \
	lib/LaTeXML/Post/Graphics.pm \
	blib/lib/LaTeXML/Post/Graphics.pm \
	lib/LaTeXML.pm \
	blib/lib/LaTeXML.pm \
	lib/LaTeXML/Package/url.ltxml \
	blib/lib/LaTeXML/Package/url.ltxml \
	lib/LaTeXML/Package/mcsd.ltxml \
	blib/lib/LaTeXML/Package/mcsd.ltxml


# --- MakeMaker platform_constants section:
MM_Unix_VERSION = 1.42
PERL_MALLOC_DEF = -DPERL_EXTMALLOC_DEF -Dmalloc=Perl_malloc -Dfree=Perl_mfree -Drealloc=Perl_realloc -Dcalloc=Perl_calloc


# --- MakeMaker tool_autosplit section:
# Usage: $(AUTOSPLITFILE) FileToSplit AutoDirToSplitInto
AUTOSPLITFILE = $(PERLRUN)  -e 'use AutoSplit;  autosplit($$ARGV[0], $$ARGV[1], 0, 1, 1)'



# --- MakeMaker tool_xsubpp section:


# --- MakeMaker tools_other section:
SHELL = /bin/sh
CHMOD = chmod
CP = cp
MV = mv
NOOP = $(SHELL) -c true
NOECHO = @
RM_F = rm -f
RM_RF = rm -rf
TEST_F = test -f
TOUCH = touch
UMASK_NULL = umask 0
DEV_NULL = > /dev/null 2>&1
MKPATH = $(PERLRUN) "-MExtUtils::Command" -e mkpath
EQUALIZE_TIMESTAMP = $(PERLRUN) "-MExtUtils::Command" -e eqtime
ECHO = echo
ECHO_N = echo -n
UNINST = 0
VERBINST = 0
MOD_INSTALL = $(PERLRUN) -MExtUtils::Install -e 'install({@ARGV}, '\''$(VERBINST)'\'', 0, '\''$(UNINST)'\'');'
DOC_INSTALL = $(PERLRUN) "-MExtUtils::Command::MM" -e perllocal_install
UNINSTALL = $(PERLRUN) "-MExtUtils::Command::MM" -e uninstall
WARN_IF_OLD_PACKLIST = $(PERLRUN) "-MExtUtils::Command::MM" -e warn_if_old_packlist


# --- MakeMaker makemakerdflt section:
makemakerdflt: all
	$(NOECHO) $(NOOP)


# --- MakeMaker dist section:
TAR = tar
TARFLAGS = cvf
ZIP = zip
ZIPFLAGS = -r
COMPRESS = gzip --best
SUFFIX = .gz
SHAR = shar
PREOP = $(NOECHO) $(NOOP)
POSTOP = $(NOECHO) $(NOOP)
TO_UNIX = $(NOECHO) $(NOOP)
CI = ci -u
RCS_LABEL = rcs -Nv$(VERSION_SYM): -q
DIST_CP = best
DIST_DEFAULT = tardist
DISTNAME = LaTeXML
DISTVNAME = LaTeXML-0.4.1


# --- MakeMaker macro section:


# --- MakeMaker depend section:


# --- MakeMaker cflags section:


# --- MakeMaker const_loadlibs section:


# --- MakeMaker const_cccmd section:


# --- MakeMaker post_constants section:


# --- MakeMaker pasthru section:

PASTHRU = LIB="$(LIB)"\
	LIBPERL_A="$(LIBPERL_A)"\
	LINKTYPE="$(LINKTYPE)"\
	PREFIX="$(PREFIX)"\
	OPTIMIZE="$(OPTIMIZE)"\
	PASTHRU_DEFINE="$(PASTHRU_DEFINE)"\
	PASTHRU_INC="$(PASTHRU_INC)"
TEXHASH=/usr/bin/texhash
TEXMF=/usr/local/share/texmf
STYLE_FILES=texmf/latexml.sty


# --- MakeMaker special_targets section:
.SUFFIXES: .xs .c .C .cpp .i .s .cxx .cc $(OBJ_EXT)

.PHONY: all config static dynamic test linkext manifest



# --- MakeMaker c_o section:


# --- MakeMaker xs_c section:


# --- MakeMaker xs_o section:


# --- MakeMaker top_targets section:
all :: pure_all manifypods
	$(NOECHO) $(NOOP)


pure_all :: config pm_to_blib subdirs linkext
	$(NOECHO) $(NOOP)

subdirs :: $(MYEXTLIB)
	$(NOECHO) $(NOOP)

config :: $(FIRST_MAKEFILE) $(INST_LIBDIR)$(DIRFILESEP).exists
	$(NOECHO) $(NOOP)

config :: $(INST_ARCHAUTODIR)$(DIRFILESEP).exists
	$(NOECHO) $(NOOP)

config :: $(INST_AUTODIR)$(DIRFILESEP).exists
	$(NOECHO) $(NOOP)

$(INST_AUTODIR)/.exists :: /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h
	$(NOECHO) $(MKPATH) $(INST_AUTODIR)
	$(NOECHO) $(EQUALIZE_TIMESTAMP) /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h $(INST_AUTODIR)/.exists

	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_AUTODIR)

$(INST_LIBDIR)/.exists :: /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)
	$(NOECHO) $(EQUALIZE_TIMESTAMP) /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h $(INST_LIBDIR)/.exists

	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_LIBDIR)

$(INST_ARCHAUTODIR)/.exists :: /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h
	$(NOECHO) $(MKPATH) $(INST_ARCHAUTODIR)
	$(NOECHO) $(EQUALIZE_TIMESTAMP) /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h $(INST_ARCHAUTODIR)/.exists

	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_ARCHAUTODIR)

config :: $(INST_MAN1DIR)$(DIRFILESEP).exists
	$(NOECHO) $(NOOP)


$(INST_MAN1DIR)/.exists :: /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h
	$(NOECHO) $(MKPATH) $(INST_MAN1DIR)
	$(NOECHO) $(EQUALIZE_TIMESTAMP) /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h $(INST_MAN1DIR)/.exists

	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_MAN1DIR)

config :: $(INST_MAN3DIR)$(DIRFILESEP).exists
	$(NOECHO) $(NOOP)


$(INST_MAN3DIR)/.exists :: /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h
	$(NOECHO) $(MKPATH) $(INST_MAN3DIR)
	$(NOECHO) $(EQUALIZE_TIMESTAMP) /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h $(INST_MAN3DIR)/.exists

	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_MAN3DIR)

help:
	perldoc ExtUtils::MakeMaker


# --- MakeMaker linkext section:

linkext :: $(LINKTYPE)
	$(NOECHO) $(NOOP)


# --- MakeMaker dlsyms section:


# --- MakeMaker dynamic section:

dynamic :: $(FIRST_MAKEFILE) $(INST_DYNAMIC) $(INST_BOOT)
	$(NOECHO) $(NOOP)


# --- MakeMaker dynamic_bs section:

BOOTSTRAP =


# --- MakeMaker dynamic_lib section:


# --- MakeMaker static section:

## $(INST_PM) has been moved to the all: target.
## It remains here for awhile to allow for old usage: "make static"
static :: $(FIRST_MAKEFILE) $(INST_STATIC)
	$(NOECHO) $(NOOP)


# --- MakeMaker static_lib section:


# --- MakeMaker manifypods section:

POD2MAN_EXE = $(PERLRUN) "-MExtUtils::Command::MM" -e pod2man "--"
POD2MAN = $(POD2MAN_EXE)


manifypods : pure_all  \
	bin/latexmlpost \
	bin/latexmlfind \
	bin/latexml \
	lib/LaTeXML/Object.pm \
	lib/LaTeXML/Document.pm \
	lib/LaTeXML/Font.pm \
	lib/LaTeXML/Model.pm \
	lib/LaTeXML/MathParser.pm \
	lib/LaTeXML/Rewrite.pm \
	lib/LaTeXML/Parameters.pm \
	lib/LaTeXML/Definition.pm \
	lib/LaTeXML/Mouth.pm \
	lib/LaTeXML/Gullet.pm \
	lib/LaTeXML/State.pm \
	lib/LaTeXML/Stomach.pm \
	lib/LaTeXML/Token.pm \
	lib/LaTeXML/Error.pm \
	lib/LaTeXML/Number.pm \
	lib/LaTeXML/Package.pm \
	lib/LaTeXML/Global.pm \
	lib/LaTeXML.pm \
	lib/LaTeXML/Box.pm \
	lib/LaTeXML/Post.pm \
	lib/LaTeXML/Object.pm \
	lib/LaTeXML/Document.pm \
	lib/LaTeXML/Font.pm \
	lib/LaTeXML/Model.pm \
	lib/LaTeXML/MathParser.pm \
	lib/LaTeXML/Rewrite.pm \
	lib/LaTeXML/Parameters.pm \
	lib/LaTeXML/Definition.pm \
	lib/LaTeXML/Mouth.pm \
	lib/LaTeXML/Gullet.pm \
	lib/LaTeXML/State.pm \
	lib/LaTeXML/Stomach.pm \
	lib/LaTeXML/Token.pm \
	lib/LaTeXML/Error.pm \
	lib/LaTeXML/Number.pm \
	lib/LaTeXML/Package.pm \
	lib/LaTeXML/Global.pm \
	lib/LaTeXML.pm \
	lib/LaTeXML/Box.pm \
	lib/LaTeXML/Post.pm
	$(NOECHO) $(POD2MAN) --section=1 --perm_rw=$(PERM_RW)\
	  bin/latexmlpost $(INST_MAN1DIR)/latexmlpost.$(MAN1EXT) \
	  bin/latexmlfind $(INST_MAN1DIR)/latexmlfind.$(MAN1EXT) \
	  bin/latexml $(INST_MAN1DIR)/latexml.$(MAN1EXT) 
	$(NOECHO) $(POD2MAN) --section=3 --perm_rw=$(PERM_RW)\
	  lib/LaTeXML/Object.pm $(INST_MAN3DIR)/LaTeXML::Object.$(MAN3EXT) \
	  lib/LaTeXML/Document.pm $(INST_MAN3DIR)/LaTeXML::Document.$(MAN3EXT) \
	  lib/LaTeXML/Font.pm $(INST_MAN3DIR)/LaTeXML::Font.$(MAN3EXT) \
	  lib/LaTeXML/Model.pm $(INST_MAN3DIR)/LaTeXML::Model.$(MAN3EXT) \
	  lib/LaTeXML/MathParser.pm $(INST_MAN3DIR)/LaTeXML::MathParser.$(MAN3EXT) \
	  lib/LaTeXML/Rewrite.pm $(INST_MAN3DIR)/LaTeXML::Rewrite.$(MAN3EXT) \
	  lib/LaTeXML/Parameters.pm $(INST_MAN3DIR)/LaTeXML::Parameters.$(MAN3EXT) \
	  lib/LaTeXML/Definition.pm $(INST_MAN3DIR)/LaTeXML::Definition.$(MAN3EXT) \
	  lib/LaTeXML/Mouth.pm $(INST_MAN3DIR)/LaTeXML::Mouth.$(MAN3EXT) \
	  lib/LaTeXML/Gullet.pm $(INST_MAN3DIR)/LaTeXML::Gullet.$(MAN3EXT) \
	  lib/LaTeXML/State.pm $(INST_MAN3DIR)/LaTeXML::State.$(MAN3EXT) \
	  lib/LaTeXML/Stomach.pm $(INST_MAN3DIR)/LaTeXML::Stomach.$(MAN3EXT) \
	  lib/LaTeXML/Token.pm $(INST_MAN3DIR)/LaTeXML::Token.$(MAN3EXT) \
	  lib/LaTeXML/Error.pm $(INST_MAN3DIR)/LaTeXML::Error.$(MAN3EXT) \
	  lib/LaTeXML/Number.pm $(INST_MAN3DIR)/LaTeXML::Number.$(MAN3EXT) \
	  lib/LaTeXML/Package.pm $(INST_MAN3DIR)/LaTeXML::Package.$(MAN3EXT) \
	  lib/LaTeXML/Global.pm $(INST_MAN3DIR)/LaTeXML::Global.$(MAN3EXT) \
	  lib/LaTeXML.pm $(INST_MAN3DIR)/LaTeXML.$(MAN3EXT) \
	  lib/LaTeXML/Box.pm $(INST_MAN3DIR)/LaTeXML::Box.$(MAN3EXT) \
	  lib/LaTeXML/Post.pm $(INST_MAN3DIR)/LaTeXML::Post.$(MAN3EXT) 




# --- MakeMaker processPL section:


# --- MakeMaker installbin section:

$(INST_SCRIPT)/.exists :: /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h
	$(NOECHO) $(MKPATH) $(INST_SCRIPT)
	$(NOECHO) $(EQUALIZE_TIMESTAMP) /usr/lib/perl5/5.8.6/i386-linux-thread-multi/CORE/perl.h $(INST_SCRIPT)/.exists

	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_SCRIPT)

EXE_FILES = bin/latexml bin/latexmlpost bin/latexmlfind bin/dlmfpost

FIXIN = $(PERLRUN) "-MExtUtils::MY" -e "MY->fixin(shift)"

pure_all :: $(INST_SCRIPT)/latexmlpost $(INST_SCRIPT)/latexmlfind $(INST_SCRIPT)/dlmfpost $(INST_SCRIPT)/latexml
	$(NOECHO) $(NOOP)

realclean ::
	$(RM_F) $(INST_SCRIPT)/latexmlpost $(INST_SCRIPT)/latexmlfind $(INST_SCRIPT)/dlmfpost $(INST_SCRIPT)/latexml

$(INST_SCRIPT)/latexmlpost: bin/latexmlpost $(FIRST_MAKEFILE) $(INST_SCRIPT)/.exists
	$(NOECHO) $(RM_F) $(INST_SCRIPT)/latexmlpost
	$(CP) bin/latexmlpost $(INST_SCRIPT)/latexmlpost
	$(FIXIN) $(INST_SCRIPT)/latexmlpost
	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_SCRIPT)/latexmlpost

$(INST_SCRIPT)/latexmlfind: bin/latexmlfind $(FIRST_MAKEFILE) $(INST_SCRIPT)/.exists
	$(NOECHO) $(RM_F) $(INST_SCRIPT)/latexmlfind
	$(CP) bin/latexmlfind $(INST_SCRIPT)/latexmlfind
	$(FIXIN) $(INST_SCRIPT)/latexmlfind
	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_SCRIPT)/latexmlfind

$(INST_SCRIPT)/dlmfpost: bin/dlmfpost $(FIRST_MAKEFILE) $(INST_SCRIPT)/.exists
	$(NOECHO) $(RM_F) $(INST_SCRIPT)/dlmfpost
	$(CP) bin/dlmfpost $(INST_SCRIPT)/dlmfpost
	$(FIXIN) $(INST_SCRIPT)/dlmfpost
	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_SCRIPT)/dlmfpost

$(INST_SCRIPT)/latexml: bin/latexml $(FIRST_MAKEFILE) $(INST_SCRIPT)/.exists
	$(NOECHO) $(RM_F) $(INST_SCRIPT)/latexml
	$(CP) bin/latexml $(INST_SCRIPT)/latexml
	$(FIXIN) $(INST_SCRIPT)/latexml
	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_SCRIPT)/latexml


# --- MakeMaker subdirs section:

# none

# --- MakeMaker clean_subdirs section:
clean_subdirs :
	$(NOECHO) $(NOOP)


# --- MakeMaker clean section:

# Delete temporary files but do not touch installed files. We don't delete
# the Makefile here so a later make realclean still has a makefile to use.

clean :: clean_subdirs
	-$(RM_RF) ./blib $(MAKE_APERL_FILE) $(INST_ARCHAUTODIR)/extralibs.all $(INST_ARCHAUTODIR)/extralibs.ld perlmain.c tmon.out mon.out so_locations pm_to_blib *$(OBJ_EXT) *$(LIB_EXT) perl.exe perl perl$(EXE_EXT) $(BOOTSTRAP) $(BASEEXT).bso $(BASEEXT).def lib$(BASEEXT).def $(BASEEXT).exp $(BASEEXT).x core core.*perl.*.? *perl.core core.[0-9] core.[0-9][0-9] core.[0-9][0-9][0-9] core.[0-9][0-9][0-9][0-9] core.[0-9][0-9][0-9][0-9][0-9]
	-$(MV) $(FIRST_MAKEFILE) $(MAKEFILE_OLD) $(DEV_NULL)


# --- MakeMaker realclean_subdirs section:
realclean_subdirs :
	$(NOECHO) $(NOOP)


# --- MakeMaker realclean section:

# Delete temporary files (via clean) and also delete installed files
realclean purge ::  clean realclean_subdirs
	$(RM_RF) $(INST_AUTODIR) $(INST_ARCHAUTODIR)
	$(RM_RF) $(DISTVNAME)
	$(RM_F)  blib/lib/LaTeXML/dtd/LaTeXML.dtd blib/lib/LaTeXML/Package/pspicture.ltxml blib/lib/LaTeXML/dtd/LaTeXML-MathML-OpenMath.dtd blib/lib/LaTeXML/State.pm blib/lib/LaTeXML/Package/amsbsy.ltxml
	$(RM_F) blib/lib/LaTeXML/Util/Transform.pm blib/lib/LaTeXML/Post/PurgeXMath.pm blib/lib/LaTeXML/Package/euscript.ltxml blib/lib/LaTeXML/Package/amsmath.ltxml blib/lib/LaTeXML/Package/color.ltxml
	$(RM_F) blib/lib/LaTeXML/Util/Color.pm blib/lib/LaTeXML/Package/graphics.ltxml blib/lib/LaTeXML/Package/alltt.ltxml blib/lib/LaTeXML/Package/amsfonts.ltxml blib/lib/LaTeXML/dtd/core.xsl.tail
	$(RM_F) blib/lib/LaTeXML/Package/makeidx.ltxml blib/lib/LaTeXML/Package/amsopn.ltxml blib/lib/LaTeXML/Package/DLMFmath.ltxml blib/lib/LaTeXML/Package/eufrak.ltxml blib/lib/LaTeXML/Package/graphicx.ltxml
	$(RM_F) blib/lib/LaTeXML/Package/hyperref.ltxml blib/lib/LaTeXML/Post/Graphics.pm blib/lib/LaTeXML/Package/mcsd.ltxml blib/lib/LaTeXML/dtd/xhtml.xsl.head blib/lib/LaTeXML/Parameters.pm $(MAKEFILE_OLD)
	$(RM_F) blib/lib/LaTeXML/Font.pm blib/lib/LaTeXML.pm blib/lib/LaTeXML/dtd/LaTeXML.css blib/lib/LaTeXML/Package/DLMF.ltxml blib/lib/LaTeXML/Package/ae.ltxml blib/lib/LaTeXML/Post/SVG.pm
	$(RM_F) blib/lib/LaTeXML/Post/XSLT.pm blib/lib/LaTeXML/Post/MathImages.pm blib/lib/LaTeXML/Definition.pm blib/lib/LaTeXML/Package/latexml.ltxml blib/lib/LaTeXML/Package/comment.ltxml
	$(RM_F) blib/lib/LaTeXML/Package/keyval.ltxml blib/lib/LaTeXML/Post.pm blib/lib/LaTeXML/Package/TeX.ltxml blib/lib/LaTeXML/Box.pm blib/lib/LaTeXML/Number.pm blib/lib/LaTeXML/Token.pm
	$(RM_F) blib/lib/LaTeXML/Stomach.pm blib/lib/LaTeXML/dtd/LaTeXML-MathML.dtd blib/lib/LaTeXML/Error.pm blib/lib/LaTeXML/Util/Pathname.pm blib/lib/LaTeXML/Package/amstext.ltxml blib/lib/LaTeXML/Util/LibXML.pm
	$(RM_F) $(FIRST_MAKEFILE) blib/lib/LaTeXML/MathGrammar blib/lib/LaTeXML/Package/LaTeX.ltxml blib/lib/LaTeXML/Post/MathML.pm blib/lib/LaTeXML/Mouth.pm blib/lib/LaTeXML/Package.pm
	$(RM_F) blib/lib/LaTeXML/Package/pst-node.ltxml blib/lib/LaTeXML/Package/eucal.ltxml blib/lib/LaTeXML/Package/url.ltxml blib/lib/LaTeXML/Global.pm blib/lib/LaTeXML/Package/pstricks.ltxml
	$(RM_F) blib/lib/LaTeXML/Package/DLMFbib.ltxml blib/lib/LaTeXML/Package/html.ltxml blib/lib/LaTeXML/dtd/DLMF.dtd blib/lib/LaTeXML/Package/article.ltxml blib/lib/LaTeXML/dtd/html.xsl.head
	$(RM_F) blib/lib/LaTeXML/Gullet.pm blib/lib/LaTeXML/Package/acronym.ltxml blib/lib/LaTeXML/Rewrite.pm blib/lib/LaTeXML/Package/amsxtra.ltxml blib/lib/LaTeXML/MathParser.pm
	$(RM_F) blib/lib/LaTeXML/Package/amsrefs.ltxml blib/lib/LaTeXML/Package/amssymb.ltxml blib/lib/LaTeXML/dtd/catalog blib/lib/LaTeXML/Document.pm blib/lib/LaTeXML/Util/Geometry.pm blib/lib/LaTeXML/Model.pm
	$(RM_F) blib/lib/LaTeXML/Post/MathML.pm.save blib/lib/LaTeXML/Object.pm blib/lib/LaTeXML/Post/OpenMath.pm


# --- MakeMaker metafile section:
metafile :
	$(NOECHO) $(ECHO) '# http://module-build.sourceforge.net/META-spec.html' > META.yml
	$(NOECHO) $(ECHO) '#XXXXXXX This is a prototype!!!  It will change in the future!!! XXXXX#' >> META.yml
	$(NOECHO) $(ECHO) 'name:         LaTeXML' >> META.yml
	$(NOECHO) $(ECHO) 'version:      0.4.1' >> META.yml
	$(NOECHO) $(ECHO) 'version_from: lib/LaTeXML.pm' >> META.yml
	$(NOECHO) $(ECHO) 'installdirs:  site' >> META.yml
	$(NOECHO) $(ECHO) 'requires:' >> META.yml
	$(NOECHO) $(ECHO) '    Image::Magick:                 0' >> META.yml
	$(NOECHO) $(ECHO) '    Parse::RecDescent:             0' >> META.yml
	$(NOECHO) $(ECHO) '    XML::LibXML:                   1.57' >> META.yml
	$(NOECHO) $(ECHO) '    XML::LibXML::XPathContext:     0' >> META.yml
	$(NOECHO) $(ECHO) '    XML::LibXSLT:                  1.57' >> META.yml
	$(NOECHO) $(ECHO) '' >> META.yml
	$(NOECHO) $(ECHO) 'distribution_type: module' >> META.yml
	$(NOECHO) $(ECHO) 'generated_by: ExtUtils::MakeMaker version 6.17' >> META.yml


# --- MakeMaker metafile_addtomanifest section:
metafile_addtomanifest:
	$(NOECHO) $(PERLRUN) -MExtUtils::Manifest=maniadd -e 'eval { maniadd({q{META.yml} => q{Module meta-data (added by MakeMaker)}}) } ' \
	-e '    or print "Could not add META.yml to MANIFEST: $${'\''@'\''}\n"'


# --- MakeMaker dist_basics section:
distclean :: realclean distcheck
	$(NOECHO) $(NOOP)

distcheck :
	$(PERLRUN) "-MExtUtils::Manifest=fullcheck" -e fullcheck

skipcheck :
	$(PERLRUN) "-MExtUtils::Manifest=skipcheck" -e skipcheck

manifest :
	$(PERLRUN) "-MExtUtils::Manifest=mkmanifest" -e mkmanifest

veryclean : realclean
	$(RM_F) *~ *.orig */*~ */*.orig



# --- MakeMaker dist_core section:

dist : $(DIST_DEFAULT) $(FIRST_MAKEFILE)
	$(NOECHO) $(PERLRUN) -l -e 'print '\''Warning: Makefile possibly out of date with $(VERSION_FROM)'\''' \
	-e '    if -e '\''$(VERSION_FROM)'\'' and -M '\''$(VERSION_FROM)'\'' < -M '\''$(FIRST_MAKEFILE)'\'';'

tardist : $(DISTVNAME).tar$(SUFFIX)
	$(NOECHO) $(NOOP)

uutardist : $(DISTVNAME).tar$(SUFFIX)
	uuencode $(DISTVNAME).tar$(SUFFIX) $(DISTVNAME).tar$(SUFFIX) > $(DISTVNAME).tar$(SUFFIX)_uu

$(DISTVNAME).tar$(SUFFIX) : distdir
	$(PREOP)
	$(TO_UNIX)
	$(TAR) $(TARFLAGS) $(DISTVNAME).tar $(DISTVNAME)
	$(RM_RF) $(DISTVNAME)
	$(COMPRESS) $(DISTVNAME).tar
	$(POSTOP)

zipdist : $(DISTVNAME).zip
	$(NOECHO) $(NOOP)

$(DISTVNAME).zip : distdir
	$(PREOP)
	$(ZIP) $(ZIPFLAGS) $(DISTVNAME).zip $(DISTVNAME)
	$(RM_RF) $(DISTVNAME)
	$(POSTOP)

shdist : distdir
	$(PREOP)
	$(SHAR) $(DISTVNAME) > $(DISTVNAME).shar
	$(RM_RF) $(DISTVNAME)
	$(POSTOP)


# --- MakeMaker distdir section:
distdir : metafile metafile_addtomanifest
	$(RM_RF) $(DISTVNAME)
	$(PERLRUN) "-MExtUtils::Manifest=manicopy,maniread" \
		-e "manicopy(maniread(),'$(DISTVNAME)', '$(DIST_CP)');"



# --- MakeMaker dist_test section:

disttest : distdir
	cd $(DISTVNAME) && $(ABSPERLRUN) Makefile.PL
	cd $(DISTVNAME) && $(MAKE) $(PASTHRU)
	cd $(DISTVNAME) && $(MAKE) test $(PASTHRU)


# --- MakeMaker dist_ci section:

ci :
	$(PERLRUN) "-MExtUtils::Manifest=maniread" \
	  -e "@all = keys %{ maniread() };" \
	  -e "print(qq{Executing $(CI) @all\n}); system(qq{$(CI) @all});" \
	  -e "print(qq{Executing $(RCS_LABEL) ...\n}); system(qq{$(RCS_LABEL) @all});"


# --- MakeMaker install section:

install :: all pure_install doc_install

install_perl :: all pure_perl_install doc_perl_install

install_site :: all pure_site_install doc_site_install

install_vendor :: all pure_vendor_install doc_vendor_install

pure_install :: pure_$(INSTALLDIRS)_install

doc_install :: doc_$(INSTALLDIRS)_install

pure__install : pure_site_install
	$(NOECHO) $(ECHO) INSTALLDIRS not defined, defaulting to INSTALLDIRS=site

doc__install : doc_site_install
	$(NOECHO) $(ECHO) INSTALLDIRS not defined, defaulting to INSTALLDIRS=site

pure_perl_install ::
	$(NOECHO) $(MOD_INSTALL) \
		read $(PERL_ARCHLIB)/auto/$(FULLEXT)/.packlist \
		write $(DESTINSTALLARCHLIB)/auto/$(FULLEXT)/.packlist \
		$(INST_LIB) $(DESTINSTALLPRIVLIB) \
		$(INST_ARCHLIB) $(DESTINSTALLARCHLIB) \
		$(INST_BIN) $(DESTINSTALLBIN) \
		$(INST_SCRIPT) $(DESTINSTALLSCRIPT) \
		$(INST_MAN1DIR) $(DESTINSTALLMAN1DIR) \
		$(INST_MAN3DIR) $(DESTINSTALLMAN3DIR)
	$(NOECHO) $(WARN_IF_OLD_PACKLIST) \
		$(SITEARCHEXP)/auto/$(FULLEXT)


pure_site_install ::
	$(NOECHO) $(MOD_INSTALL) \
		read $(SITEARCHEXP)/auto/$(FULLEXT)/.packlist \
		write $(DESTINSTALLSITEARCH)/auto/$(FULLEXT)/.packlist \
		$(INST_LIB) $(DESTINSTALLSITELIB) \
		$(INST_ARCHLIB) $(DESTINSTALLSITEARCH) \
		$(INST_BIN) $(DESTINSTALLSITEBIN) \
		$(INST_SCRIPT) $(DESTINSTALLSCRIPT) \
		$(INST_MAN1DIR) $(DESTINSTALLSITEMAN1DIR) \
		$(INST_MAN3DIR) $(DESTINSTALLSITEMAN3DIR)
	$(NOECHO) $(WARN_IF_OLD_PACKLIST) \
		$(PERL_ARCHLIB)/auto/$(FULLEXT)

pure_vendor_install ::
	$(NOECHO) $(MOD_INSTALL) \
		read $(VENDORARCHEXP)/auto/$(FULLEXT)/.packlist \
		write $(DESTINSTALLVENDORARCH)/auto/$(FULLEXT)/.packlist \
		$(INST_LIB) $(DESTINSTALLVENDORLIB) \
		$(INST_ARCHLIB) $(DESTINSTALLVENDORARCH) \
		$(INST_BIN) $(DESTINSTALLVENDORBIN) \
		$(INST_SCRIPT) $(DESTINSTALLSCRIPT) \
		$(INST_MAN1DIR) $(DESTINSTALLVENDORMAN1DIR) \
		$(INST_MAN3DIR) $(DESTINSTALLVENDORMAN3DIR)

doc_perl_install ::
	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
	-$(NOECHO) $(DOC_INSTALL) \
		"Module" "$(NAME)" \
		"installed into" "$(INSTALLPRIVLIB)" \
		LINKTYPE "$(LINKTYPE)" \
		VERSION "$(VERSION)" \
		EXE_FILES "$(EXE_FILES)" \
		>> $(DESTINSTALLARCHLIB)/perllocal.pod

doc_site_install ::
	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
	-$(NOECHO) $(DOC_INSTALL) \
		"Module" "$(NAME)" \
		"installed into" "$(INSTALLSITELIB)" \
		LINKTYPE "$(LINKTYPE)" \
		VERSION "$(VERSION)" \
		EXE_FILES "$(EXE_FILES)" \
		>> $(DESTINSTALLARCHLIB)/perllocal.pod

doc_vendor_install ::
	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
	-$(NOECHO) $(DOC_INSTALL) \
		"Module" "$(NAME)" \
		"installed into" "$(INSTALLVENDORLIB)" \
		LINKTYPE "$(LINKTYPE)" \
		VERSION "$(VERSION)" \
		EXE_FILES "$(EXE_FILES)" \
		>> $(DESTINSTALLARCHLIB)/perllocal.pod


uninstall :: uninstall_from_$(INSTALLDIRS)dirs

uninstall_from_perldirs ::
	$(NOECHO) $(UNINSTALL) $(PERL_ARCHLIB)/auto/$(FULLEXT)/.packlist

uninstall_from_sitedirs ::
	$(NOECHO) $(UNINSTALL) $(SITEARCHEXP)/auto/$(FULLEXT)/.packlist

uninstall_from_vendordirs ::
	$(NOECHO) $(UNINSTALL) $(VENDORARCHEXP)/auto/$(FULLEXT)/.packlist


# --- MakeMaker force section:
# Phony target to force checking subdirectories.
FORCE:
	$(NOECHO) $(NOOP)


# --- MakeMaker perldepend section:


# --- MakeMaker makefile section:

# We take a very conservative approach here, but it's worth it.
# We move Makefile to Makefile.old here to avoid gnu make looping.
$(FIRST_MAKEFILE) : Makefile.PL $(CONFIGDEP)
	$(NOECHO) $(ECHO) "Makefile out-of-date with respect to $?"
	$(NOECHO) $(ECHO) "Cleaning current config before rebuilding Makefile..."
	$(NOECHO) $(RM_F) $(MAKEFILE_OLD)
	$(NOECHO) $(MV)   $(FIRST_MAKEFILE) $(MAKEFILE_OLD)
	-$(MAKE) -f $(MAKEFILE_OLD) clean $(DEV_NULL) || $(NOOP)
	$(PERLRUN) Makefile.PL "DLMF"
	$(NOECHO) $(ECHO) "==> Your Makefile has been rebuilt. <=="
	$(NOECHO) $(ECHO) "==> Please rerun the make command.  <=="
	false



# --- MakeMaker staticmake section:

# --- MakeMaker makeaperl section ---
MAP_TARGET    = perl
FULLPERL      = /usr/bin/perl

$(MAP_TARGET) :: static $(MAKE_APERL_FILE)
	$(MAKE) -f $(MAKE_APERL_FILE) $@

$(MAKE_APERL_FILE) : $(FIRST_MAKEFILE)
	$(NOECHO) $(ECHO) Writing \"$(MAKE_APERL_FILE)\" for this $(MAP_TARGET)
	$(NOECHO) $(PERLRUNINST) \
		Makefile.PL DIR= \
		MAKEFILE=$(MAKE_APERL_FILE) LINKTYPE=static \
		MAKEAPERL=1 NORECURS=1 CCCDLFLAGS= \
		DLMF


# --- MakeMaker test section:

TEST_VERBOSE=0
TEST_TYPE=test_$(LINKTYPE)
TEST_FILE = test.pl
TEST_FILES = t/*.t
TESTDB_SW = -d

testdb :: testdb_$(LINKTYPE)

test :: $(TEST_TYPE)

test_dynamic :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-e" "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)

testdb_dynamic :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) $(TESTDB_SW) "-I$(INST_LIB)" "-I$(INST_ARCHLIB)" $(TEST_FILE)

test_ : test_dynamic

test_static :: test_dynamic
testdb_static :: testdb_dynamic


# --- MakeMaker ppd section:
# Creates a PPD (Perl Package Description) for a binary distribution.
ppd:
	$(NOECHO) $(ECHO) '<SOFTPKG NAME="$(DISTNAME)" VERSION="0,4,1,0">' > $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    <TITLE>$(DISTNAME)</TITLE>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    <ABSTRACT></ABSTRACT>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    <AUTHOR>Bruce Miller &lt;bruce.miller@nist.gov&gt;</AUTHOR>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    <IMPLEMENTATION>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <DEPENDENCY NAME="Image-Magick" VERSION="0,0,0,0" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <DEPENDENCY NAME="Parse-RecDescent" VERSION="0,0,0,0" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <DEPENDENCY NAME="XML-LibXML" VERSION="1,57,0,0" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <DEPENDENCY NAME="XML-LibXML-XPathContext" VERSION="0,0,0,0" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <DEPENDENCY NAME="XML-LibXSLT" VERSION="1,57,0,0" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <OS NAME="$(OSNAME)" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <ARCHITECTURE NAME="i386-linux-thread-multi" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <CODEBASE HREF="" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    </IMPLEMENTATION>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '</SOFTPKG>' >> $(DISTNAME).ppd


# --- MakeMaker pm_to_blib section:

pm_to_blib: $(TO_INST_PM)
	$(NOECHO) $(PERLRUN) -MExtUtils::Install -e 'pm_to_blib({@ARGV}, '\''$(INST_LIB)/auto'\'', '\''$(PM_FILTER)'\'')'\
	  lib/LaTeXML/Package/amsmath.ltxml blib/lib/LaTeXML/Package/amsmath.ltxml \
	  lib/LaTeXML/Util/Color.pm blib/lib/LaTeXML/Util/Color.pm \
	  lib/LaTeXML/Model.pm blib/lib/LaTeXML/Model.pm \
	  lib/LaTeXML/Package/eufrak.ltxml blib/lib/LaTeXML/Package/eufrak.ltxml \
	  lib/LaTeXML/MathGrammar blib/lib/LaTeXML/MathGrammar \
	  lib/LaTeXML/Definition.pm blib/lib/LaTeXML/Definition.pm \
	  lib/LaTeXML/Post/MathImages.pm blib/lib/LaTeXML/Post/MathImages.pm \
	  lib/LaTeXML/Package/graphicx.ltxml blib/lib/LaTeXML/Package/graphicx.ltxml \
	  lib/LaTeXML/Package/LaTeX.ltxml blib/lib/LaTeXML/Package/LaTeX.ltxml \
	  lib/LaTeXML/State.pm blib/lib/LaTeXML/State.pm \
	  lib/LaTeXML/Token.pm blib/lib/LaTeXML/Token.pm \
	  lib/LaTeXML/dtd/core.xsl.tail blib/lib/LaTeXML/dtd/core.xsl.tail \
	  lib/LaTeXML/Package/amstext.ltxml blib/lib/LaTeXML/Package/amstext.ltxml \
	  lib/LaTeXML/Package/amsbsy.ltxml blib/lib/LaTeXML/Package/amsbsy.ltxml \
	  lib/LaTeXML/Package/makeidx.ltxml blib/lib/LaTeXML/Package/makeidx.ltxml \
	  lib/LaTeXML/dtd/DLMF.dtd blib/lib/LaTeXML/dtd/DLMF.dtd \
	  lib/LaTeXML/Post/OpenMath.pm blib/lib/LaTeXML/Post/OpenMath.pm \
	  lib/LaTeXML/Package/amssymb.ltxml blib/lib/LaTeXML/Package/amssymb.ltxml \
	  lib/LaTeXML/dtd/catalog blib/lib/LaTeXML/dtd/catalog \
	  lib/LaTeXML/Package/amsxtra.ltxml blib/lib/LaTeXML/Package/amsxtra.ltxml \
	  lib/LaTeXML/Post/MathML.pm blib/lib/LaTeXML/Post/MathML.pm \
	  lib/LaTeXML/Package/ae.ltxml blib/lib/LaTeXML/Package/ae.ltxml \
	  lib/LaTeXML/Package/euscript.ltxml blib/lib/LaTeXML/Package/euscript.ltxml \
	  lib/LaTeXML/Package/pspicture.ltxml blib/lib/LaTeXML/Package/pspicture.ltxml \
	  lib/LaTeXML/Package/article.ltxml blib/lib/LaTeXML/Package/article.ltxml \
	  lib/LaTeXML/Package/amsfonts.ltxml blib/lib/LaTeXML/Package/amsfonts.ltxml \
	  lib/LaTeXML/Font.pm blib/lib/LaTeXML/Font.pm \
	  lib/LaTeXML/Post/XSLT.pm blib/lib/LaTeXML/Post/XSLT.pm \
	  lib/LaTeXML/Rewrite.pm blib/lib/LaTeXML/Rewrite.pm \
	  lib/LaTeXML/dtd/xhtml.xsl.head blib/lib/LaTeXML/dtd/xhtml.xsl.head \
	  lib/LaTeXML/Gullet.pm blib/lib/LaTeXML/Gullet.pm \
	  lib/LaTeXML/Package/hyperref.ltxml blib/lib/LaTeXML/Package/hyperref.ltxml \
	  lib/LaTeXML/Error.pm blib/lib/LaTeXML/Error.pm \
	  lib/LaTeXML/Package/DLMFbib.ltxml blib/lib/LaTeXML/Package/DLMFbib.ltxml \
	  lib/LaTeXML/Util/Transform.pm blib/lib/LaTeXML/Util/Transform.pm \
	  lib/LaTeXML/Post/MathML.pm.save blib/lib/LaTeXML/Post/MathML.pm.save \
	  lib/LaTeXML/Package/pst-node.ltxml blib/lib/LaTeXML/Package/pst-node.ltxml \
	  lib/LaTeXML/Box.pm blib/lib/LaTeXML/Box.pm \
	  lib/LaTeXML/Post.pm blib/lib/LaTeXML/Post.pm \
	  lib/LaTeXML/Package/DLMF.ltxml blib/lib/LaTeXML/Package/DLMF.ltxml \
	  lib/LaTeXML/Post/SVG.pm blib/lib/LaTeXML/Post/SVG.pm \
	  lib/LaTeXML/Document.pm blib/lib/LaTeXML/Document.pm \
	  lib/LaTeXML/dtd/LaTeXML.dtd blib/lib/LaTeXML/dtd/LaTeXML.dtd \
	  lib/LaTeXML/Package/keyval.ltxml blib/lib/LaTeXML/Package/keyval.ltxml \
	  lib/LaTeXML/Util/Geometry.pm blib/lib/LaTeXML/Util/Geometry.pm \
	  lib/LaTeXML/Package/comment.ltxml blib/lib/LaTeXML/Package/comment.ltxml \
	  lib/LaTeXML/Package/latexml.ltxml blib/lib/LaTeXML/Package/latexml.ltxml \
	  lib/LaTeXML/MathParser.pm blib/lib/LaTeXML/MathParser.pm \
	  lib/LaTeXML/Mouth.pm blib/lib/LaTeXML/Mouth.pm \
	  lib/LaTeXML/Package/acronym.ltxml blib/lib/LaTeXML/Package/acronym.ltxml \
	  lib/LaTeXML/Post/PurgeXMath.pm blib/lib/LaTeXML/Post/PurgeXMath.pm \
	  lib/LaTeXML/Package.pm blib/lib/LaTeXML/Package.pm \
	  lib/LaTeXML/Package/alltt.ltxml blib/lib/LaTeXML/Package/alltt.ltxml \
	  lib/LaTeXML/Global.pm blib/lib/LaTeXML/Global.pm \
	  lib/LaTeXML/Util/Pathname.pm blib/lib/LaTeXML/Util/Pathname.pm \
	  lib/LaTeXML/Object.pm blib/lib/LaTeXML/Object.pm \
	  lib/LaTeXML/Package/pstricks.ltxml blib/lib/LaTeXML/Package/pstricks.ltxml \
	  lib/LaTeXML/Package/amsrefs.ltxml blib/lib/LaTeXML/Package/amsrefs.ltxml \
	  lib/LaTeXML/dtd/LaTeXML.css blib/lib/LaTeXML/dtd/LaTeXML.css \
	  lib/LaTeXML/dtd/html.xsl.head blib/lib/LaTeXML/dtd/html.xsl.head \
	  lib/LaTeXML/dtd/LaTeXML-MathML.dtd blib/lib/LaTeXML/dtd/LaTeXML-MathML.dtd \
	  lib/LaTeXML/Parameters.pm blib/lib/LaTeXML/Parameters.pm \
	  lib/LaTeXML/Util/LibXML.pm blib/lib/LaTeXML/Util/LibXML.pm \
	  lib/LaTeXML/Package/color.ltxml blib/lib/LaTeXML/Package/color.ltxml \
	  lib/LaTeXML/Package/amsopn.ltxml blib/lib/LaTeXML/Package/amsopn.ltxml \
	  lib/LaTeXML/Stomach.pm blib/lib/LaTeXML/Stomach.pm \
	  lib/LaTeXML/Package/eucal.ltxml blib/lib/LaTeXML/Package/eucal.ltxml \
	  lib/LaTeXML/Package/TeX.ltxml blib/lib/LaTeXML/Package/TeX.ltxml \
	  lib/LaTeXML/Package/DLMFmath.ltxml blib/lib/LaTeXML/Package/DLMFmath.ltxml \
	  lib/LaTeXML/dtd/LaTeXML-MathML-OpenMath.dtd blib/lib/LaTeXML/dtd/LaTeXML-MathML-OpenMath.dtd \
	  lib/LaTeXML/Number.pm blib/lib/LaTeXML/Number.pm \
	  lib/LaTeXML/Package/graphics.ltxml blib/lib/LaTeXML/Package/graphics.ltxml \
	  lib/LaTeXML/Package/html.ltxml blib/lib/LaTeXML/Package/html.ltxml \
	  lib/LaTeXML/Post/Graphics.pm blib/lib/LaTeXML/Post/Graphics.pm \
	  lib/LaTeXML.pm blib/lib/LaTeXML.pm \
	  lib/LaTeXML/Package/url.ltxml blib/lib/LaTeXML/Package/url.ltxml \
	  lib/LaTeXML/Package/mcsd.ltxml blib/lib/LaTeXML/Package/mcsd.ltxml 
	$(NOECHO) $(TOUCH) $@

# --- MakeMaker selfdocument section:


# --- MakeMaker postamble section:
all :: blib/lib/LaTeXML/MathGrammar.pm

blib/lib/LaTeXML/MathGrammar.pm: lib/LaTeXML/MathGrammar
	$(PERLRUN) -MParse::RecDescent - lib/LaTeXML/MathGrammar LaTeXML::MathGrammar
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)/LaTeXML
	$(MV) MathGrammar.pm blib/lib/LaTeXML/MathGrammar.pm

all :: blib/lib/LaTeXML/dtd/LaTeXML-html.xsl

all :: blib/lib/LaTeXML/dtd/LaTeXML-xhtml.xsl

blib/lib/LaTeXML/dtd/LaTeXML-html.xsl: lib/LaTeXML/dtd/html.xsl.head lib/LaTeXML/dtd/core.xsl.tail
	$(PERLRUN) -e 'while(<>){print;}' lib/LaTeXML/dtd/html.xsl.head lib/LaTeXML/dtd/core.xsl.tail \
	> blib/lib/LaTeXML/dtd/LaTeXML-html.xsl

blib/lib/LaTeXML/dtd/LaTeXML-xhtml.xsl: lib/LaTeXML/dtd/xhtml.xsl.head lib/LaTeXML/dtd/core.xsl.tail
	$(PERLRUN) -e 'while(<>){print;}' lib/LaTeXML/dtd/xhtml.xsl.head lib/LaTeXML/dtd/core.xsl.tail \
	> blib/lib/LaTeXML/dtd/LaTeXML-xhtml.xsl

install::
	$(MKPATH) $(TEXMF)/tex/latex/latexml/
	$(CP) $(STYLE_FILES) $(TEXMF)/tex/latex/latexml/
	$(TEXHASH)



# End.
