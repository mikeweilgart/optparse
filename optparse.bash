# Optparse - a BASH wrapper for getopts
# @author : nk412 / nagarjuna.412@gmail.com

optparse_usage=""
optparse_contractions=""
optparse_defaults=""
optparse_process=""
optparse_arguments_string=""

# -----------------------------------------------------------------------------------------------------------------------------
optparse.throw_error() {
        echo "OPTPARSE: ERROR: $1"
        exit 1
}

# -----------------------------------------------------------------------------------------------------------------------------
optparse.define() {
        if [ $# -lt 3 ]; then
                optparse.throw_error "optparse.define <short> <long> <variable> [<desc>] [<default>] [<value>]"
        fi
        while [ "$#" -gt 0 ] ; do
                local option="$1"
                local key="$( echo $option | awk -F "=" '{print $1}' )";
                local value="$( echo $option | awk -F "=" '{print $2}' )";

                #essentials: shortname, longname, description
                case "$key" in
                  (short)
                        local shortname="$value"
                        if [ ${#shortname} -ne 1 ]; then
                                optparse.throw_error "short name expected to be one character long"
                        fi
                        local short="-${shortname}"
                    ;;
                  (long)
                        local longname="$value"
                        if [ ${#longname} -lt 2 ]; then
                                optparse.throw_error "long name expected to be atleast one character long"
                        fi
                        local long="--${longname}"
                    ;;
                  (desc)
                        local desc="$value"
                    ;;
                  (default)
                        local default="$value"
                    ;;
                  (variable)
                        local variable="$value"
                    ;;
                  (value)
                        local val="$value"
                    ;;
                esac
                shift
        done

        if [ "$variable" = "" ]; then
                optparse.throw_error "You must give a variable for option: ($short/$long)"
        fi

        if [ "$val" = "" ]; then
                val="\$OPTARG"
        fi

        # build OPTIONS and help
        optparse_usage="${optparse_usage}#NL#TB${short} $(printf "%-25s %s" "${long}:" "${desc}")"
        if [ "$default" != "" ]; then
                optparse_usage="${optparse_usage} [default:$default]"
        fi
        optparse_contractions="${optparse_contractions}#NL#TB#TB${long})#NL#TB#TB#TBparams=\"\$params ${short}\";;"
        if [ "$default" != "" ]; then
                optparse_defaults="${optparse_defaults}#NL${variable}=${default}"
        fi
        optparse_arguments_string="${optparse_arguments_string}${shortname}"
        if [ "$val" = "\$OPTARG" ]; then
                optparse_arguments_string="${optparse_arguments_string}:"
        fi
        optparse_process="${optparse_process}#NL#TB#TB${shortname})#NL#TB#TB#TB${variable}=\"$val\";;"
}

# -----------------------------------------------------------------------------------------------------------------------------
optparse.build() {
        local build_file="$(mktemp -t optparse-XXXXXXXXXX.tmp)"
        # On BSD systems this could just be "mktemp -t optparse", but this way it will succeed with GNU mktemp as well.

        # Building getopts header here

        # Function usage
        cat << EOF > $build_file
usage() {
cat << XXX
usage: \$0 [OPTIONS]

OPTIONS:
        $optparse_usage

        -? --help  :  usage

XXX
}

# Contract long options into short options
params=""
while [ \$# -ne 0 ]; do
        param="\$1"
        shift

        case "\$param" in
                $optparse_contractions
                "-?"|--help)
                        usage
                        exit 0;;
                *)
                        if [[ "\$param" == --* ]]; then
                                echo -e "Unrecognized long option: \$param"
                                usage
                                exit 1
                        fi
                        params="\$params \"\$param\"";;
        esac
done

eval set -- "\$params"

# Set default variable values
$optparse_defaults

# Process using getopts
while getopts "$optparse_arguments_string" option; do
        case \$option in
                # Substitute actions for different variables
                $optparse_process
                :)
                        echo "Option - \$OPTARG requires an argument"
                        exit 1;;
                *)
                        usage
                        exit 1;;
        esac
done

# Clean up after self
rm $build_file

EOF

        sed -i '' 's/#NL/\
/g;s/#TB/	/g' "$build_file"

        # Unset global variables
        unset optparse_usage
        unset optparse_process
        unset optparse_arguments_string
        unset optparse_defaults
        unset optparse_contractions

        # Return file name to parent
        echo "$build_file"
}
# -----------------------------------------------------------------------------------------------------------------------------
