
#@ File (label = "Select image folder", style = "directory") input
#@ File (label = "Select graticule", style = "file") graticule
#@ Integer (label = "Number of samples in block", min=1, max=2, value=2) Nsamples
#@ Float (label = "cut thickness (in um)", style="format:#.##") depth
suffix = ".tif"

parent = File.getParent(input);
name = File.getNameWithoutExtension(parent);
parts = split(name, "_");
SID  = parts[0];

// Get pixel size from graticule
	open(graticule);
	Stack.setXUnit("pixel");
	Stack.getDimensions(width, height, channels, slices, frames);
	run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width=1 pixel_height=1 voxel_depth=1");
	setTool("line");
	
	Dialog.createNonBlocking("Pixel Size");
	Dialog.setLocation(100,0);
	Dialog.addMessage("Draw a line along the graticule scale");
	Dialog.addNumber("lenght in mm on the graticule", 1);
	Dialog.addMessage("(graticule full lenght is 10mm)");
	Dialog.show();
	
	grat = Dialog.getNumber();
	run("Set Measurements...", "area mean bounding redirect=None decimal=3");
	run("Measure");
	length = getResult("Length");
	size = grat * 1000 / length
	Stack.getDimensions(width, height, channels, slices, frames);
	run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width="+size+" pixel_height="+size+" voxel_depth="+depth+"");
	Stack.setXUnit("um");
	close("Results")
	close();

//Open 20% res stack
	File.openSequence(input, " step=5");
	rename("Z DOWNSAMPLED 5X.tif");
	Stack.setXUnit("pixel");
	Stack.getDimensions(width, height, channels, slices, frames);
	run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width=1 pixel_height=1 voxel_depth=1");
	setTool("rectangle");

	if (Nsamples == 1) {
	// select area to crop and save for later processing of whole stack
		Dialog.createNonBlocking("ROI Selection - 1 sample");
		Dialog.setLocation(100,0);
		Dialog.addMessage("Select the ROI that include all your sample \nOnce done click OK");
		Dialog.show();
		
		roiManager("Add");
		roiManager("Save", parent + File.separator + SID +"_CropArea.roi");
		roiManager("measure");
		area = getResult("Width");
		gaussian = area/20;
		close("Results");
		close();

	// Create folders to save data
		FFoutput = parent + File.separator + SID + "_cropped_FF";
		output = parent + File.separator + SID + "_cropped";
		File.makeDirectory(FFoutput);
		File.makeDirectory(output);
	
	// Run Croping, Flat Field correction and scalling on all stack images
		setBatchMode("hide");
		processFolder_1samp(input);
	} 
	
	else (Nsamples == 2) {
	// select Left and Right areas to crop and save for later processing of whole stack
		// Left sample
		Dialog.createNonBlocking("ROI Selection - 2 samples - Left");
		Dialog.setLocation(100,0);
		Dialog.addMessage("Select the ROI that include all the sample on the Left \nOnce done click OK");
		Dialog.show();	
		roiManager("Add");
		roiManager("Save", parent + File.separator + SID +"_Left_CropArea.roi");
		roiManager("measure");
		Larea = getResult("Width");
		Lgaussian = Larea/20;
		close("Results");
		
		// Right sample
		Dialog.createNonBlocking("ROI Selection  - 2 samples - Right");
		Dialog.setLocation(screenWidth-100,0);
		Dialog.addMessage("Select the ROI that include all the sample on the Right \nOnce done click OK");
		Dialog.show();
		roiManager("Add");
		roiManager("Save", parent + File.separator + SID +"_Right_CropArea.roi");
		roiManager("measure");
		Rarea = getResult("Width");
		Rgaussian = Rarea/20;
		close("Results");
		close();

	// Create folders to save data
		// Left sample
		Left = parent + File.separator + SID + "_Left";
		File.makeDirectory(Left);
		LFFoutput = Left + File.separator + SID + "_Left_cropped_FF";
		Loutput = Left + File.separator + SID + "_Left_cropped";
		File.makeDirectory(LFFoutput);
		File.makeDirectory(Loutput);
		// Right sample		
		Right = parent + File.separator + SID + "_Right";
		File.makeDirectory(Right);
		RFFoutput = Right + File.separator + SID + "_Right_cropped_FF";
		Routput = Right + File.separator + SID + "_Right_cropped";
		File.makeDirectory(RFFoutput);
		File.makeDirectory(Routput);
	
	// Run Croping, Flat Field correction and scalling on all stack images
		setBatchMode("hide");
		processFolder_2samp(input);
	} 
		run("Close All");
		close("Results");
		close("ROI Manager");
		close("Log");

// Create Z downsampled stacks for quick data browsing
File.openSequence(input, " step=5 scale=10.0");
setVoxelSize(size*10, size*10, depth*5, "um");
saveAs("Tiff", parent + File.separator + SID +"_scaled_10");
close();

showMessage("Sample " + SID + " processed");
	
// functions
// 1 sample:
function processFolder_1samp(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(endsWith(list[i], suffix))
			processFile_1samp(input, parent, list[i], i);
	}
}
function processFile_1samp(input, parent, file, i) {
	print("I'm in Nsamples 1 function, my name is Camille!");
	showProgress(i, list.length);
	open(input+File.separator+file);
	active = getImageID();
	run("Invert");
	roiManager("Select", 0);
	run("Crop");
	// Add pixel size to image
	Stack.setXUnit("um");
	run("Properties...", "channels="+channels+" slices=1 frames=1 pixel_width="+size+" pixel_height="+size+" voxel_depth="+depth+"");
	saveAs("Tiff", output+File.separator+file);	
	// Pseudo Flat Field Correction (Gaussian of radius a twentieth the size of the image and dividing the original image by it) creating a 32bit image
	selectImage(active);
	run("Duplicate...", "gaussian");
	blur = getImageID();
	run("Measure");
	mean = getResult("Mean");
	run("Subtract...", "value="+mean+"");
	run("Gaussian Blur...", "sigma="+gaussian+"");
	imageCalculator("Subtract create 32-bit", active, blur);
	saveAs("Tiff", FFoutput+File.separator+file);
	close("\\Others");
	run("Clear Results");
}

// for 2 samples:
function processFolder_2samp(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(endsWith(list[i], suffix))
			processFile_2samp(input, parent, list[i], i);
	}
}
function processFile_2samp(input, parent, file, i) {
	print("I'm in Nsamples 2 function! Help! How did i get here!!???");
	showProgress(i, list.length);
	open(input+File.separator+file);
	active = getImageID();
	run("Invert");
	// add pixel size
	Stack.setXUnit("um");
	run("Properties...", "channels="+channels+" slices=1 frames=1 pixel_width="+size+" pixel_height="+size+" voxel_depth="+depth+"");
	// Left sample
		roiManager("Select", 0);
		run("Duplicate...", " ");
		LeftID = getImageID();
		saveAs("Tiff", Loutput+File.separator+file);
		// Pseudo Flat Field Correction 
		run("Duplicate...", "gaussian");
		Lblur = getImageID();
		run("Measure");
		mean = getResult("Mean", 0);
		run("Subtract...", "value="+mean+"");
		run("Gaussian Blur...", "sigma="+Lgaussian+"");
		imageCalculator("Subtract create 32-bit", LeftID, Lblur);
		saveAs("Tiff", LFFoutput+File.separator+file);
		close()
		close(LeftID);
		close(Lblur);
	// Right sample
		selectImage(active);
		roiManager("Select", 1);
		run("Crop");
		saveAs("Tiff", Routput+File.separator+file);
		// Pseudo Flat Field Correction 
		run("Duplicate...", "gaussian");
		Rblur = getImageID();
		run("Measure");
		mean = getResult("Mean", 1);
		run("Subtract...", "value="+mean+"");
		run("Gaussian Blur...", "sigma="+Rgaussian+"");
		imageCalculator("Subtract create 32-bit", active, Rblur);
		saveAs("Tiff", RFFoutput+File.separator+file);
		close("*");	
		run("Clear Results");
}
