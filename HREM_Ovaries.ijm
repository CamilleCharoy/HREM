

#@ File (label = "Select SID folder", style = "directory") input
#@ File (label = "Select graticule", style = "file") graticule
#@ Integer (label = "Number of samples in block", style = "slider", min=1, max=2) Nsample
#@ float (label = "cut thickness (in um)", style="format:#.##") depth
suffix = ".tif";

name = File.getNameWithoutExtension(input);
parts = split(name, "_");
SID  = parts[0];

var area = 1;
var Larea = 1;
var Rarea = 1;

var Gaussian = 1;
var LGaussian = 1;
var RGaussian = 1;

images = input + File.separator + "Channel 1";

// Get pixel size from graticule
	open(graticule);
	Stack.getDimensions(width, height, channels, slices, frames);
	channelNumber = channels;
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
	size = grat * 1000 / length;
	close("Results");
	close();
//Open 20% resolution stack to select area to crop and save area for later processing of whole stack
	if (channelNumber == 4) {
		File.openSequence(images, " step=5");
		keepChannel2(input);
	} else {
		File.openSequence(images, " step=5");
	}
	rename("Z DOWNSAMPLED 5X.tif");
	RemovePixelSize();
	setTool("rectangle");
	if (Nsample == 1){
			Dialog.createNonBlocking("ROI Selection - 1 sample");
			Dialog.setLocation(100,0);
			Dialog.addMessage("Select the ROI to include the whole sample \nOnce done click OK");
			Dialog.show();
		AreaCal(0, input, SID, area, "_");
		Gaussian = area/20;
		close();
			// Create folder structure
			FFoutput = input + File.separator + SID + "_cropped_FF";
			output = input + File.separator + SID + "_cropped";
			FFoutput20 = input + File.separator + SID + "_cropped_FF_scaled_20";
			output20 = input + File.separator + SID + "_cropped_scaled_20";
			File.makeDirectory(FFoutput);
			File.makeDirectory(output);
			File.makeDirectory(FFoutput20);
			File.makeDirectory(output20);		
		setBatchMode("hide");
		processFolder_1samp(images);
	} if (Nsample == 2){
		// LEFT sample
			Dialog.createNonBlocking("ROI Selection - 2 samples - LEFT sample");
			Dialog.setLocation(100,0);
			Dialog.addMessage("Select the ROI to include the whole sample on the LEFT \nOnce done click OK");
			Dialog.show();
		AreaCal(0, input, SID, Larea, "Left_");
		LGaussian = area/20;
			// Create folder structure
			left = input + File.separator + SID + "_Left";
			LFFoutput = left + File.separator + SID + "_Left_cropped_FF";
			Loutput = left + File.separator + SID + "_Left_cropped";
			LFFoutput20 = left + File.separator + SID + "_Left_cropped_FF_scaled_20";
			Loutput20 = left + File.separator + SID + "_Left_cropped_scaled_20";
			File.makeDirectory(left);			
			File.makeDirectory(LFFoutput);
			File.makeDirectory(Loutput);
			File.makeDirectory(LFFoutput20);
			File.makeDirectory(Loutput20);	
		// RIGHT sample
			Dialog.createNonBlocking("ROI Selection - 2 samples - RIGHT sample");
			Dialog.setLocation(400,0);
			Dialog.addMessage("Select the ROI to include the whole sample on the RIGHT \nOnce done click OK");
			Dialog.show();
		AreaCal(1, input, SID, Rarea, "Right_");
		RGaussian = area/20;
		close();
			// Create folder structure
			right = input + File.separator + SID + "_Right";
			RFFoutput = right + File.separator + SID + "_Right_cropped_FF";
			Routput = right + File.separator + SID + "_Right_cropped";
			RFFoutput20 = right + File.separator + SID + "_Right_cropped_FF_scaled_20";
			Routput20 = right + File.separator + SID + "_Right_cropped_scaled_20";
			File.makeDirectory(right);
			File.makeDirectory(RFFoutput);
			File.makeDirectory(Routput);
			File.makeDirectory(RFFoutput20);
			File.makeDirectory(Routput20);	
		setBatchMode("hide");
		processFolder_2samp(images);
	}		
close("ROI Manager");
close("*");

// Create Z downsampled stacks for data quick browsing
if (Nsample == 1){
	SaveStacks(output20, FFoutput20, images, "_");
} if (Nsample == 2){
	SaveStacks(Loutput20, LFFoutput20, images, "Left_");
	SaveStacks(Routput20, RFFoutput20, images, "Right_");
}
showMessage("Sample " + SID + " processed");

///////////////////////////////////////////////////////////////////////////////////////////////////////////	

// FUNCTIONS:
function RemovePixelSize() {
// remove pixel size to image
    Stack.setXUnit("pixel");
    Stack.getDimensions(width, height, channels, slices, frames);
    run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width=1 pixel_height=1 voxel_depth=1");
}
function AddPixelSize (size, depth){
// add pixel size to image
    Stack.setXUnit("um");
    Stack.getDimensions(width, height, channels, slices, frames);
    run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width="+size+" pixel_height="+size+" voxel_depth="+depth+"");
}
function AreaCal(index, input, SID, area, type){
// Calculate area of the sample ROI, used to calculate the radius of the gaussian filter  
	roiManager("Add");
	roiManager("select", index);
	roiManager("Save", input+File.separator+ SID + type +"CropArea.roi");
	roiManager("measure");
	area = getResult("Width");
	close("Results");
}
function PseudoFlatField(active, radius, output) {
// Removes background and does a pseudo flat field correction, (Gaussian of radius a twentieth the size of the image and dividing 
//the original image by it) creating a 32bit image
    run("Duplicate...", "gaussian");
    blur = getImageID();
    run("Measure");
    mean = getResult("Mean", 0);
    run("Subtract...", "value="+mean+"");
    run("Gaussian Blur...", "sigma="+radius+"");
    imageCalculator("Divide create 32-bit", active, blur);
    saveAs("Tiff", output+File.separator+"FF"+file);
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
function processFolder_1samp(images) {
	list = getFileList(images);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(endsWith(list[i], suffix))
			processFile_1samp(input, list[i], i);
	}
}
function processFile_1samp(input, file, i) {
	showProgress(i, list.length);
	if (channelNumber == 4){
		open(images+File.separator+file);
		start = getImageID();
		run("Invert");
		roiManager("Select", 0);
		Stack.setChannel(2);
		run("Duplicate...", "  channels=2");
		active = getImageID();
		selectImage(start);
		close();
	} else {
		open(images+File.separator+file);
		active = getImageID();
		run("Invert");
		roiManager("Select", 0);
		run("Crop");
	}
	AddPixelSize (size, depth);
	saveAs("Tiff", output+File.separator+file);	
	// Create 20% downscalled image for images with names finishing by 0 or 5 only
	a = endsWith(i, "0");
	b = endsWith(i, "5");
	if (a==true || b==true) {
		Downscale(output20, file);
		} 
	selectImage(active);
	PseudoFlatField(active, Gaussian, FFoutput);
	selectImage(active);
	close();
	if (a==true || b==true){
		Downscale(FFoutput20, file);
		} 
}
function processFolder_2samp(images) {
	list = getFileList(images);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(endsWith(list[i], suffix))
			processFile_2samp(input, list[i], i);
	}
}
function processFile_2samp(input, file, i) {
	showProgress(i, list.length);
	if (channelNumber == 4){
		open(images+File.separator+file);
		AddPixelSize (size, depth);
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
		open(images+File.separator+file);
		AddPixelSize (size, depth);
		start = getImageID();
		run("Invert");
		roiManager("Select", 0);
		run("Duplicate...", " ");
		LeftID = getImageID();
		selectImage(start);
		roiManager("Select", 1);
		run("Crop");
		RightID = getImageID();
	}
	selectImage(LeftID);
	saveAs("Tiff", Loutput+File.separator+file);	
	a = endsWith(i, "0");
	b = endsWith(i, "5");
	if (a==true || b==true) { 
		Downscale(Loutput20, file);
	} 
	PseudoFlatField(LeftID, LGaussian, LFFoutput);
	selectImage(LeftID);
	close(LeftID);
	if (a==true || b==true){ 
		Downscale(LFFoutput20, file);
	} 
	selectImage(RightID);
	saveAs("Tiff", Routput+File.separator+file);	
	if (a==true || b==true) { 
		Downscale(Routput20, file);
	} 
	PseudoFlatField(RightID, RGaussian, RFFoutput);
	selectImage(RightID);
	close(RightID);
	if (a==true || b==true){ 
		Downscale(RFFoutput20, file);
	} 
}
function Downscale(output, file){
//save 20% resolution image
	run("Scale...", "x=0.2 y=0.2 interpolation=Bilinear average create");
	saveAs("Tiff", output+File.separator+file);
	close();
}
function SaveStacks(input1, input2, input3, type){
// Save images in a 20% resolution downsample stack and a 10% resolution of the row images
	File.openSequence(input1);
	setVoxelSize(size*5, size*5, depth*5, "um");
	saveAs("Tiff", input+File.separator+ SID + type + "cropped_scaled_20");
	close();	
	File.openSequence(input2);
	setVoxelSize(size*5, size*5, depth*5, "um");
	saveAs("Tiff", input+File.separator+ SID + type + "cropped_FF_scaled_20");
	close();
	File.openSequence(input3, " step=5 scale=10.0");
	setVoxelSize(size*10, size*10, depth*5, "um");
	saveAs("Tiff", input+File.separator+ SID +"_scaled_10");
	close();
}
