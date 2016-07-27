# GStreamerScripts

[create_gst_uninstalled_env.sh](https://github.com/PetrosKataras/GStreamerScripts/blob/master/scripts/create-gst-uninstalled-env.sh)  
  
Creates a complete gst uninstalled setup for you. In an uninstalled setup the libraries are not installed system wide but instead live in a normal directory on your filesystem.  

Currently the script will create this directory under your home directory with the name gst i.e `~/gst`. Inside this directory besides all the libraries there is also an executable symlink that will look like the following : `~/gst/gst-$BRANCH` where `$BRANCH` is the branch you passed in as an option to the script. The default for this value is master. 

The magic happens whenever you run an application that uses GStreamer through this script i.e `~/gst/gst-$BRANCH /path/to/my/app` or alternatively if you enter the environment and work directly from there i.e executing `~/gst/gst-$BRANCH` enters the environment for the specific shell session and every application that executes inside this shell will load the latest versions of GStreamer and plugins.

It will install gst dependencies and then download, configure appropriately and compile the following for you : `gstreamer`, `gst-plugins-base`, `gst-plugins-good`, `gst-plugins-bad`, `gst-plugins-ugly`, `gst-libav`. If you are on Raspbian it will also do the same steps for `gst-omx`. 

The script handles a few options like the branch that you want to work with, or if it should skip dependency installation ( useful after a first run ). Type `sh create_gst_uninstalled_env.sh --help` to check the available options.
