function cropMatlab(inputVideoPath, outputName, ROI)
    % This function only crop one video
    % inputVideoPath - String: name of input video (entire path)
    % outputVideoPath - String: name of output video (entire path)
    % cropRectangle - [xmin ymin xMax yMax]
  
    reader = VideoReader(inputVideoPath);
    writer = VideoWriter(outputName, 'MPEG-4');
    writer.FrameRate =  reader.FrameRate;
    open(writer);

    width = reader.Width;
    height = reader.Height;

    cropRec = ROI;
    cropRec(3) = ROI(3) - ROI(1);
    cropRec(4) = ROI(4) - ROI(2);

    nFrame = reader.NumFrames;
    
    if cropRec(3) > width && cropRec(4) > height
        disp('width or height of ROI exceeds boundary of video')
        exit; 
    end
    
    % Read and write each frame
    %croppedFrame = zeros(1,nFrame);
    i = 1;
  
    while hasFrame(reader)
        frame = readFrame(reader); % Read the next frame     
        croppedFrame = imcrop(frame, cropRec); 
        writeVideo(writer, croppedFrame);
        i = i+1;    
    end
    close(writer);
end
