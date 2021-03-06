# convertImageToXsm.tcl --
#
#       This file implements the Tcl code for converting an image (TIFF, JPEG, BMP, PNG)
#      into the native xsmurf file format.
#
#   Copyright 2008 CEA, IRFU, Saclay, France
#   Written by Pierre Kestener (pierre.kestener@cea.fr).
#
package require vtk
package require fileutil

# conv2xsm --
# usage: conv2xsm str str
#
# Convert an image file (TIFF, JPEG, BMP or PNG file format) into the native xsmurf file format
# using the tcl bindings of the VTK library (http://www.vtk.org)
#
# Parameters:
#   string - input file name
#   string - output file name (without extension)
#
# Options:
#
# Return value:
#   None.

proc conv2xsm {iname oname} {

    if {[file exists $iname] != 1} {
	return -code error "Input file does not exists !"
    }
    set iExtension [file extension $iname]
    
    # create reader object
    switch -exact -- $iExtension {
	.tif {
	    vtkTIFFReader iReader
	}
	.jpg {
	    vtkJPEGReader iReader
	}
	.png {
	    vtkPNGReader iReader
	}
	.pnm {
	    vtkPNMReader iReader
	}
	.bmp {
	    vtkBMPReader iReader
	}
    }
    
    # read input
    iReader SetFileName $iname
    iReader Update
    
    # get dimensions
    set dimX [lindex [[iReader GetOutput] GetDimensions] 0]
    set dimY [lindex [[iReader GetOutput] GetDimensions] 1]
    #puts "$dimX $dimY"

    set nbScalarComponents [[iReader GetOutput] GetNumberOfScalarComponents]
    #puts "nbScalarComponents : $nbScalarComponents"

    if {$nbScalarComponents == 1} {
	# cast luminance image to float data type
	vtkImageCast ic
	ic SetOutputScalarTypeToFloat
	ic SetInputConnection [iReader GetOutputPort]
    } else {
	# convert color image to a gray scale valued image
	vtkImageLuminance il
	il SetInputConnection [iReader GetOutputPort]
	
	# cast luminance image to float data type
	vtkImageCast ic
	ic SetOutputScalarTypeToFloat
	ic SetInputConnection [il GetOutputPort]
    }


    #
    # write to a temp directory; use .
    #
   set dir "."
    
    # make sure it is writeable first
    if {[catch {set channel [open "$dir/test.tmp" "w"]}] == 0 } {
	close $channel
	file delete -force "$dir/test.tmp"
	
	# create writer object
	vtkMetaImageWriter iWriter
	
	# write data to file
	iWriter SetInputConnection [ic GetOutputPort]
	iWriter SetFileName "${oname}"
	iWriter SetRAWFileName "${oname}.xsm"
	iWriter Write

	# delete Meta Image header file
	file delete -force $oname

	# insert xsmurf-specific header
	set size [expr $dimX * $dimY]
	::fileutil::insertIntoFile ${oname}.xsm 0 "Binary 1 ${dimX}x${dimY} ${size}(4 byte reals)\n"
	
	# load image
	iload ${oname}.xsm ${oname}.tmp
	iswapraw ${oname}.tmp ${oname}
	delete ${oname}.tmp

	# delete writer
	iWriter Delete

    }

    # delete other vtk-specific structures
    iReader Delete
    ic Delete
    if {$nbScalarComponents != 1} {
	il Delete
    }

    puts "${oname} loaded."

}
