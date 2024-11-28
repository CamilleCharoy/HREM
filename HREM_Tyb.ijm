
#@ File (label = "Select image folder", style = "directory") input
#@ File (label = "Select graticule", style = "file") graticule
#@ Integer (label = "Number of samples in block", style = "slider", min=1, max=2) Nsamples
#@ Float (label = "cut thickness (in um)", style="format:#.##") depth
suffix = ".tif"

parent = File.getParent(input);
name = File.getNameWithoutExtension(parent);
parts = split(name, "_");
SID  = parts[0];

// Get pixel size from graticule
	open(graticule);
	Stack.getDimensions(width, height, channels, slices, frames);
	chanelNumber = channels
	RemovePixelSize();
	
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
	close("Results")
	close();

//Open 20% res stack
if (chanelNumber == 4) {
	File.openSequence(input, " step=5");
	keepChannel2(input);
} else {File.openSequence(input, " step=5");}
	rename("Z DOWNSAMPLED 5X.tif");
	RemovePixelSize();
	setTool("rectangle");

	if (Nsamples == 1) {
	// select area to crop and save for later processing of whole stack
		Dialog.createNonBlocking("ROI Selection - 1 sample");
		Dialog.setLocation(100,0);
		Dialog.addMessage("Select the ROI to include the whole sample \nOnce done click OK");
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
	
	if (Nsamples == 2) {
	// select Left and Right areas to crop and save for later processing of whole stack
		// Left sample
		Dialog.createNonBlocking("ROI Selection - 2 samples - Left");
		Dialog.setLocation(100,0);
		Dialog.addMessage("Select the ROI to include the whole sample on the Left \nOnce done click OK");
		Dialog.show();
		
		roiManager("Add");
		roiManager("Save", parent + File.separator + SID +"_Left_CropArea.roi");
		roiManager("measure");
		Larea = getResult("Width");
		Lgaussian = Larea/20;
		close("Results");
		
		// Right sample
		Dialog.createNonBlocking("ROI Selection  - 2 samples - Right");
		Dialog.setLocation(200,0);
		Dialog.addMessage("Select the ROI to include the whole sample on the Right \nOnce done click OK");
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
if (chanelNumber == 4) {
	File.openSequence(input, " step=5 scale=10.0");
	keepChannel2(input);
} else {File.openSequence(input, " step=5 scale=10.0");}
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
	showProgress(i, list.length);
	if (chanelNumber == 4) {
		open(input+File.separator+file);
		start = getImageID();
		run("Invert");
		roiManager("Select", 0);
		Stack.setChannel(2);
		run("Duplicate...", "  channels=2");
		active = getImageID();
		selectImage(start);
		close();
	} else {
		open(input+File.separator+file);
		run("Invert");
		roiManager("Select", 0);
		active = getImageID();
		run("Crop");
		}
	AddPixelSize (size, depth);
	saveAs("Tiff", output+File.separator+file);	
	selectImage(active);
	PseudoFlatField(active, gaussian, FFoutput);
	selectImage(active);
	close();
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
	showProgress(i, list.length);
	if (chanelNumber == 4) {
		open(input+File.separator+file);
		start = getImageID();
		run("Invert");
		roiManager("Select", 0);
		Stack.setChannel(2);
		run("Duplicate...", "  channels=2");
		LeftID = getImageID();
		selectImage(start);
		roiManager("Select", 1);
		Stack.setChannel(2);
		run("Duplicate...", "  channels=2");
		RightID = getImageID();
		selectImage(start);
		close();
	} else {
		open(input+File.separator+file);
		run("Invert");
		start = getImageID();
		roiManager("Select", 0);
		run("Duplicate...");
		LeftID = getImageID();
		roiManager("Select", 1);
		run("Crop");		
		RightID = getImageID();
	}
	selectImage(LeftID);
	AddPixelSize (size, depth);	
	saveAs("Tiff", Loutput+File.separator+file);
	PseudoFlatField(LeftID, Lgaussian, LFFoutput);
	close();
	selectImage(RightID);
	saveAs("Tiff", Routput+File.separator+file);
	PseudoFlatField(RightID, Rgaussian, RFFoutput);
	close();
}

function AddPixelSize (size, depth){
// add pixel size to image
    Stack.setXUnit("um");
    Stack.getDimensions(width, height, channels, slices, frames);
    run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width="+size+" pixel_height="+size+" voxel_depth="+depth+"");
}

function RemovePixelSize() {
// remove pixel size to image
    Stack.setXUnit("pixel");
    Stack.getDimensions(width, height, channels, slices, frames);
    run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width=1 pixel_height=1 voxel_depth=1");
}

function PseudoFlatField(active, gaussian, output) {
// Removes background and does a pseudo flat field correction
    run("Duplicate...", "gaussian");
    blur = getImageID();
    run("Measure");
    mean = getResult("Mean", 0);
    run("Subtract...", "value="+mean+"");
    run("Gaussian Blur...", "sigma="+gaussian+"");
    imageCalculator("Subtract create 32-bit", active, blur);
    saveAs("Tiff", output+File.separator+file);
    close();
    selectImage(blur);
    close();
    run("Clear Results");
}

function keepChannel2(input) { 
// Only keep 2nd channel (green) of each image
	Stack.getDimensions(width, height, channels, slices, frames);
	run("Stack to Hyperstack...", "order=xyczt(default) channels=4 slices="+slices/4+" frames=1 display=Grayscale");
	Stack.setChannel(2);
	run("Reduce Dimensionality...", "slices");
	resetMinAndMax();
}

