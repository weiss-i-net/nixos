set -l resolution 1080
set -l fov wide
set -l gopro_ip ""

function usage
    echo "Usage: gopro [-r|--resolution 1080|720|480] [-f|--fov wide|narrow|superview|linear] [-i|--ip <address>]"
    echo
    echo "Starts GoPro HERO8 Black webcam mode: finds the camera over its USB"
    echo "network link, tells it to start streaming, and pipes the stream into"
    echo "/dev/video42 via ffmpeg so apps see it as an ordinary webcam."
end

argparse 'r/resolution=' 'f/fov=' 'i/ip=' 'h/help' -- $argv
or exit 1

if set -q _flag_help
    usage
    exit 0
end
if set -q _flag_resolution
    set resolution $_flag_resolution
end
if set -q _flag_fov
    set fov $_flag_fov
end
if set -q _flag_ip
    set gopro_ip $_flag_ip
end
if test (count $argv) -gt 0
    echo "Unknown argument: $argv[1]" >&2
    usage >&2
    exit 1
end

if not contains -- $resolution 1080 720 480
    echo "Invalid resolution: $resolution (expected 1080, 720, or 480)" >&2
    exit 1
end

switch $fov
    case wide
        set fov_id 0
    case narrow
        set fov_id 2
    case superview
        set fov_id 3
    case linear
        set fov_id 4
    case '*'
        echo "Invalid fov: $fov (expected wide, narrow, superview, or linear)" >&2
        exit 1
end

if test -z "$gopro_ip"
    # Find the GoPro's USB network interface by its USB vendor ID
    # (2672 == GoPro) rather than guessing by link order -- on
    # machines with another always-up wired interface (e.g. a
    # desktop's onboard NIC), "last non-down link" can just as
    # easily pick the wrong one.
    set -l iface ""
    for dev in /sys/class/net/*/
        set -l candidate (basename $dev)
        set -l vendor_file $dev"device/../idVendor"
        if test -r $vendor_file
            set -l vendor (cat $vendor_file)
            if test "$vendor" = 2672
                set iface $candidate
                break
            end
        end
    end
    if test -z "$iface"
        echo "Could not find the GoPro's USB network interface (no net device with USB vendor ID 2672). Is it plugged in and set to 'GoPro Connect' (not MTP)?" >&2
        exit 1
    end

    set -l host_ip (ip -4 addr show dev $iface | grep -Po '(?<=inet )[\d.]+')
    if test -z "$host_ip"
        echo "Found interface $iface but it has no IPv4 address yet." >&2
        exit 1
    end

    # The camera always answers on the same /24 with the last octet forced to .51.
    set -l host_prefix (string replace -r '\.[0-9]+$' '' $host_ip)
    set gopro_ip "$host_prefix.51"
end

curl -sSf "http://$gopro_ip/gp/gpWebcam/START?res=$resolution&port=8554" >/dev/null
curl -sSf "http://$gopro_ip/gp/gpWebcam/SETTINGS?fov=$fov_id" >/dev/null

exec ffmpeg -nostdin -threads 1 \
    -i "udp://@0.0.0.0:8554?overrun_nonfatal=1&fifo_size=50000000" \
    -f:v mpegts -fflags nobuffer -vf format=yuv420p \
    -f v4l2 /dev/video42
