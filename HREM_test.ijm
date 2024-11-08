#@ File (label = "Select SID folder", style = "directory") input
#@ float (label = "cut thickness (in um)", style="format:#.##") depth
suffix = ".tif"

name = File.getNameWithoutExtension(input);
parts = split(name, "_");
SID  = parts[0];

images = input + File.separator + "Channel 1";

pattern = ".*[0]|[5]";

//Open 20% res stack to select area to crop and save area for later processing of whole stack
File.openSequence(images, " step=5");
rename("Z DOWNSAMPLED 5X.tif");
setTool("rectangle");

Dialog.createNonBlocking("ROI Selection");
Dialog.addMessage("Select the ROI that include all your sample \nOnce done click OK");
Dialog.show();

roiManager("Add");
roiManager("Save", input+File.separator+ SID +"CropArea.roi");
close();

// Get pixel size from graticule
open(input + File.separator + "Graticule.tif");
Stack.setXUnit("pixel");
run("Properties...", "channels=1 slices=1 frames=1 pixel_width=1 pixel_height=1 voxel_depth=1.0000000");
setTool("line");

run("Set Measurements...", "area bounding redirect=None decimal=3");
roiManager("select", 0);
roiManager("measure");
area = getResult("Width");
gaussian = area/20
close("Results")
makeLine(0, 0, 0, 0);

Dialog.createNonBlocking("Pixel Size");
Dialog.addMessage("Draw a line along the graticule scale");
Dialog.addNumber("lenght in mm on the graticule", 1);
Dialog.addMessage("(graticule full lenght is 10mm)");
Dialog.show();

graticule = Dialog.getNumber();
run("Measure");
length = getResult("Length");
size = graticule * 1000 / length
run("Properties...", "channels=1 slices=1 frames=1 pixel_width="+size+" pixel_height="+size+" voxel_depth=1");
Stack.setXUnit("um");
close("Results")
close();

// Create folders to save data
FFoutput = input + File.separator + SID + "_cropped_FF"
output = input + File.separator + SID + "_cropped"
FFoutput20 = input + File.separator + SID + "_cropped_FF_scaled_20"
output20 = input + File.separator + SID + "_cropped_scaled_20"
File.makeDirectory(FFoutput);
File.makeDirectory(output);
File.makeDirectory(FFoutput20);
File.makeDirectory(output20);

// Run Croping, Flat Field correction and scalling on all stack images
//setBatchMode("hide");
processFolder(images);
function processFolder(images) {
	list = getFileList(images);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i], i);
	}
}
function processFile(input, output, file, i) {
	open(images+File.separator+file);
	active = getImageID();
	run("Invert LUT");
	roiManager("Select", 0);
	run("Crop");
	// Add pixel size to image
	Stack.setXUnit("um");
	run("Properties...", "channels=1 slices=1 frames=1 pixel_width="+size+" pixel_height="+size+" voxel_depth="+depth+"");
	saveAs("Tiff", output+File.separator+file);	
	// Create 20% downscalled image for images with names finishing by 0 or 5 only
	a = endsWith(i, "0");
	b = endsWith(i, "5");
	if (a==true || b==true) {
		run("Scale...", "x=0.2 y=0.2 interpolation=Bilinear average create");
		saveAs("Tiff", output20+File.separator+file);
		close();
		} 
	// Pseudo Flat Field Correction (Gaussian of radius a twentieth the size of the image and dividing the original image by it) creating a 32bit image
	selectImage(active);
	run("Duplicate...", "gaussian");
	blur = getImageID();
	run("Gaussian Blur...", "sigma="+gaussian+"");
	imageCalculator("Divide create 32-bit", active, blur);
	saveAs("Tiff", FFoutput+File.separator+file);
	close("\\Others");
	if (a==true || b==true){
		run("Scale...", "x=0.2 y=0.2 interpolation=Bilinear average create");
		saveAs("Tiff", FFoutput20+File.separator+file);
		close();
		} 
}
close("ROI Manager");
close("*");
// Create Z downsampled stacks for data quick browsing
File.openSequence(output, " step=5 scale=20.0");
setVoxelSize(size*5, size*5, depth*5, "um");
saveAs("Tiff", input+File.separator+ SID +"_cropped_scaled_20");
close();

File.openSequence(FFoutput, " step=5 scale=20.0");
setVoxelSize(size*5, size*5, depth*5, "um");
saveAs("Tiff", input+File.separator+ SID +"_cropped_FF_scaled_20");
close();

File.openSequence(images, " step=5 scale=10.0");
setVoxelSize(size*10, size*10, depth*5, "um");
saveAs("Tiff", input+File.separator+ SID +"_scaled_10");
close();

showMessage("Sample " + SID + " processed");
	

