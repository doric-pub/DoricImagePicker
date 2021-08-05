package pub.doric.library;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Build;
import android.webkit.MimeTypeMap;

import com.github.pengfeizhou.jscore.JSONBuilder;
import com.github.pengfeizhou.jscore.JSObject;
import com.github.pengfeizhou.jscore.JSValue;
import com.github.pengfeizhou.jscore.JavaValue;

import org.json.JSONArray;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import androidx.annotation.Nullable;
import androidx.exifinterface.media.ExifInterface;
import pub.doric.DoricContext;
import pub.doric.extension.bridge.DoricMethod;
import pub.doric.extension.bridge.DoricPlugin;
import pub.doric.extension.bridge.DoricPromise;
import pub.doric.plugin.DoricJavaPlugin;
import pub.doric.utils.DoricLog;

@DoricPlugin(name = "imagePicker")
public class DoricImagePickerPlugin extends DoricJavaPlugin {
    private static final int REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY = 0x201;
    private static final int REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY = 0x202;
    private static final int REQUEST_CODE_CHOOSE_MULTI_IMAGE_FROM_GALLERY = 0x203;
    private static final int REQUEST_CODE_CHOOSE_MULTI_VIDEO_FROM_GALLERY = 0x204;
    private DoricPromise promise;
    private JSObject params;

    public DoricImagePickerPlugin(DoricContext doricContext) {
        super(doricContext);
    }

    @DoricMethod
    public void pickImage(JSObject params, DoricPromise promise) {
        JSValue sourceVal = params.getProperty("source");
        boolean useCamera = sourceVal.isNumber() && sourceVal.asNumber().toInt() == 1;
        if (useCamera) {
            JSValue cameraVal = params.getProperty("cameraDevice");

        } else {
            Intent pickImageIntent = new Intent(Intent.ACTION_GET_CONTENT);
            pickImageIntent.setType("image/*");
            getDoricContext().startActivityForResult(pickImageIntent, REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY);
            this.promise = promise;
            this.params = params;
        }
    }

    @DoricMethod
    public void pickVideo(JSObject params, DoricPromise promise) {
        JSValue sourceVal = params.getProperty("source");
        boolean useCamera = sourceVal.isNumber() && sourceVal.asNumber().toInt() == 1;
        if (useCamera) {
            JSValue cameraVal = params.getProperty("cameraDevice");

        } else {
            Intent pickImageIntent = new Intent(Intent.ACTION_GET_CONTENT);
            pickImageIntent.setType("video/*");
            getDoricContext().startActivityForResult(pickImageIntent, REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY);
            this.promise = promise;
            this.params = params;
        }
    }

    @DoricMethod
    public void pickMultiImage(JSObject params, DoricPromise promise) {
        JSValue sourceVal = params.getProperty("source");
        boolean useCamera = sourceVal.isNumber() && sourceVal.asNumber().toInt() == 1;
        if (useCamera) {
            JSValue cameraVal = params.getProperty("cameraDevice");

        } else {
            Intent pickImageIntent = new Intent(Intent.ACTION_GET_CONTENT);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                pickImageIntent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
            }
            pickImageIntent.setType("image/*");

            getDoricContext().startActivityForResult(pickImageIntent, REQUEST_CODE_CHOOSE_MULTI_IMAGE_FROM_GALLERY);
            this.promise = promise;
            this.params = params;
        }
    }

    @DoricMethod
    public void pickMultiVideo(JSObject params, DoricPromise promise) {
        JSValue sourceVal = params.getProperty("source");
        boolean useCamera = sourceVal.isNumber() && sourceVal.asNumber().toInt() == 1;
        if (useCamera) {
            JSValue cameraVal = params.getProperty("cameraDevice");

        } else {
            Intent pickImageIntent = new Intent(Intent.ACTION_GET_CONTENT);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                pickImageIntent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
            }
            pickImageIntent.setType("video/*");

            getDoricContext().startActivityForResult(pickImageIntent, REQUEST_CODE_CHOOSE_MULTI_VIDEO_FROM_GALLERY);
            this.promise = promise;
            this.params = params;
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        switch (requestCode) {
            case REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    String path = getPathFromUri(getDoricContext().getContext(), data.getData());
                    handleImageResult(path, false);
                } else {
                    // User cancelled choosing a picture.
                    handleCancelResult();
                }
                break;
            case REQUEST_CODE_CHOOSE_MULTI_IMAGE_FROM_GALLERY:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    ArrayList<String> paths = new ArrayList<>();
                    if (data.getClipData() != null) {
                        for (int i = 0; i < data.getClipData().getItemCount(); i++) {
                            paths.add(getPathFromUri(getDoricContext().getContext(), data.getClipData().getItemAt(i).getUri()));
                        }
                    } else {
                        paths.add(getPathFromUri(getDoricContext().getContext(), data.getData()));
                    }
                    handleMultiImageResult(paths, false);
                } else {
                    // User cancelled choosing a picture.
                    handleCancelResult();
                }
                break;
            case REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    String path = getPathFromUri(getDoricContext().getContext(), data.getData());
                    handleVideoResult(path);
                } else {
                    // User cancelled choosing a picture.
                    handleCancelResult();
                }
                break;
            case REQUEST_CODE_CHOOSE_MULTI_VIDEO_FROM_GALLERY:
                if (resultCode == Activity.RESULT_OK && data != null) {
                    ArrayList<String> paths = new ArrayList<>();
                    if (data.getClipData() != null) {
                        for (int i = 0; i < data.getClipData().getItemCount(); i++) {
                            paths.add(getPathFromUri(getDoricContext().getContext(), data.getClipData().getItemAt(i).getUri()));
                        }
                    } else {
                        paths.add(getPathFromUri(getDoricContext().getContext(), data.getData()));
                    }
                    handleMultiVideoResult(paths);
                } else {
                    // User cancelled choosing a picture.
                    handleCancelResult();
                }
                break;
            default:
                break;
        }
    }

    private void handleImageResult(String path, boolean shouldDeleteOriginalIfScaled) {
        if (params != null && promise != null) {
            String finalImagePath = getResizedImagePath(path);
            //delete original file if scaled
            if (finalImagePath != null && !finalImagePath.equals(path) && shouldDeleteOriginalIfScaled) {
                new File(path).delete();
            }
            promise.resolve(new JavaValue(
                    new JSONBuilder()
                            .put("filePath", finalImagePath)
                            .toJSONObject()));
        }
    }

    private void handleMultiImageResult(ArrayList<String> paths, boolean shouldDeleteOriginalIfScaled) {
        if (params != null && promise != null) {
            JSONArray jsonArray = new JSONArray();
            for (int i = 0; i < paths.size(); i++) {
                String finalImagePath = getResizedImagePath(paths.get(i));
                //delete original file if scaled
                if (finalImagePath != null
                        && !finalImagePath.equals(paths.get(i))
                        && shouldDeleteOriginalIfScaled) {
                    new File(paths.get(i)).delete();
                }
                jsonArray.put(new JSONBuilder()
                        .put("filePath", finalImagePath)
                        .toJSONObject());
            }

            promise.resolve(new JavaValue(jsonArray));
        }
    }

    private void handleVideoResult(String path) {
        if (params != null && promise != null) {
            promise.resolve(new JavaValue(
                    new JSONBuilder()
                            .put("filePath", path)
                            .toJSONObject()));
        }
    }

    private void handleMultiVideoResult(ArrayList<String> paths) {
        if (params != null && promise != null) {
            JSONArray jsonArray = new JSONArray();
            for (String path : paths) {
                jsonArray.put(new JSONBuilder()
                        .put("filePath", path)
                        .toJSONObject());
            }
            promise.resolve(new JavaValue(jsonArray));
        }
    }


    private void handleCancelResult() {
        if (promise != null) {
            promise.resolve(new JavaValue());
        }
    }

    private String getResizedImagePath(String path) {
        JSValue maxWidth = params.getProperty("maxWidth");
        JSValue maxHeight = params.getProperty("maxHeight");
        JSValue imageQuality = params.getProperty("imageQuality");
        return resizeImageIfNeeded(path,
                maxWidth.isNumber() ? maxWidth.asNumber().toDouble() : null,
                maxHeight.isNumber() ? maxHeight.asNumber().toDouble() : null,
                imageQuality.isNumber() ? imageQuality.asNumber().toInt() : null);
    }

    private static String getPathFromUri(final Context context, final Uri uri) {
        File file = null;
        InputStream inputStream = null;
        OutputStream outputStream = null;
        boolean success = false;
        try {
            String extension = getImageExtension(context, uri);
            inputStream = context.getContentResolver().openInputStream(uri);
            file = File.createTempFile("image_picker", extension, context.getCacheDir());
            file.deleteOnExit();
            outputStream = new FileOutputStream(file);
            if (inputStream != null) {
                copy(inputStream, outputStream);
                success = true;
            }
        } catch (IOException ignored) {
        } finally {
            try {
                if (inputStream != null) inputStream.close();
            } catch (IOException ignored) {
            }
            try {
                if (outputStream != null) outputStream.close();
            } catch (IOException ignored) {
                // If closing the output stream fails, we cannot be sure that the
                // target file was written in full. Flushing the stream merely moves
                // the bytes into the OS, not necessarily to the file.
                success = false;
            }
        }
        return success ? file.getPath() : null;
    }

    private static String getImageExtension(Context context, Uri uriImage) {
        String extension;

        try {
            if (uriImage.getScheme().equals(ContentResolver.SCHEME_CONTENT)) {
                extension = MimeTypeMap.getSingleton()
                        .getExtensionFromMimeType(context.getContentResolver().getType(uriImage));
            } else {
                extension = MimeTypeMap
                        .getFileExtensionFromUrl(Uri.fromFile(new File(uriImage.getPath())).toString());
            }
        } catch (Exception e) {
            extension = null;
        }

        if (extension == null || extension.isEmpty()) {
            extension = "jpg";
        }
        return "." + extension;
    }

    private static void copy(InputStream in, OutputStream out) throws IOException {
        final byte[] buffer = new byte[4 * 1024];
        int bytesRead;
        while ((bytesRead = in.read(buffer)) != -1) {
            out.write(buffer, 0, bytesRead);
        }
        out.flush();
    }

    private boolean isImageQualityValid(Integer imageQuality) {
        return imageQuality != null && imageQuality > 0 && imageQuality < 100;
    }

    private String resizeImageIfNeeded(String imagePath,
                                       @Nullable Double maxWidth,
                                       @Nullable Double maxHeight,
                                       @Nullable Integer imageQuality) {
        Bitmap bmp = BitmapFactory.decodeFile(imagePath);
        if (bmp == null) {
            return null;
        }
        boolean shouldScale =
                maxWidth != null || maxHeight != null || isImageQualityValid(imageQuality);
        if (!shouldScale) {
            return imagePath;
        }
        try {
            String[] pathParts = imagePath.split("/");
            String imageName = pathParts[pathParts.length - 1];
            File file = resizedImage(bmp, maxWidth, maxHeight, imageQuality, imageName);
            copyExif(imagePath, file.getPath());
            return file.getPath();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }


    private File resizedImage(Bitmap bmp,
                              Double maxWidth,
                              Double maxHeight,
                              Integer imageQuality,
                              String outputImageName)
            throws IOException {
        double originalWidth = bmp.getWidth() * 1.0;
        double originalHeight = bmp.getHeight() * 1.0;

        if (!isImageQualityValid(imageQuality)) {
            imageQuality = 100;
        }

        boolean hasMaxWidth = maxWidth != null;
        boolean hasMaxHeight = maxHeight != null;

        double width = hasMaxWidth ? Math.min(originalWidth, maxWidth) : originalWidth;
        double height = hasMaxHeight ? Math.min(originalHeight, maxHeight) : originalHeight;

        boolean shouldDownscaleWidth = hasMaxWidth && maxWidth < originalWidth;
        boolean shouldDownscaleHeight = hasMaxHeight && maxHeight < originalHeight;
        boolean shouldDownscale = shouldDownscaleWidth || shouldDownscaleHeight;

        if (shouldDownscale) {
            double downscaledWidth = (height / originalHeight) * originalWidth;
            double downscaledHeight = (width / originalWidth) * originalHeight;

            if (width < height) {
                if (!hasMaxWidth) {
                    width = downscaledWidth;
                } else {
                    height = downscaledHeight;
                }
            } else if (height < width) {
                if (!hasMaxHeight) {
                    height = downscaledHeight;
                } else {
                    width = downscaledWidth;
                }
            } else {
                if (originalWidth < originalHeight) {
                    width = downscaledWidth;
                } else if (originalHeight < originalWidth) {
                    height = downscaledHeight;
                }
            }
        }

        Bitmap scaledBmp = Bitmap.createScaledBitmap(bmp, (int) width, (int) height, false);
        return createImageOnExternalDirectory("/scaled_" + outputImageName, scaledBmp, imageQuality);
    }

    private File createFile(File externalFilesDirectory, String child) {
        File image = new File(externalFilesDirectory, child);
        if (!image.getParentFile().exists()) {
            image.getParentFile().mkdirs();
        }
        return image;
    }

    private File createImageOnExternalDirectory(String name, Bitmap bitmap, int imageQuality)
            throws IOException {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        boolean saveAsPNG = bitmap.hasAlpha();
        if (saveAsPNG) {
            DoricLog.d("imagePicker: compressing is not supported for type PNG. Returning the image with original quality");
        }
        bitmap.compress(
                saveAsPNG ? Bitmap.CompressFormat.PNG : Bitmap.CompressFormat.JPEG,
                imageQuality,
                outputStream);
        File imageFile = createFile(getDoricContext().getContext().getCacheDir(), name);
        FileOutputStream fileOutput = new FileOutputStream(imageFile);
        fileOutput.write(outputStream.toByteArray());
        fileOutput.close();
        return imageFile;
    }

    private void copyExif(String filePathOri, String filePathDest) {
        try {
            ExifInterface oldExif = new ExifInterface(filePathOri);
            ExifInterface newExif = new ExifInterface(filePathDest);

            List<String> attributes =
                    Arrays.asList(
                            "FNumber",
                            "ExposureTime",
                            "ISOSpeedRatings",
                            "GPSAltitude",
                            "GPSAltitudeRef",
                            "FocalLength",
                            "GPSDateStamp",
                            "WhiteBalance",
                            "GPSProcessingMethod",
                            "GPSTimeStamp",
                            "DateTime",
                            "Flash",
                            "GPSLatitude",
                            "GPSLatitudeRef",
                            "GPSLongitude",
                            "GPSLongitudeRef",
                            "Make",
                            "Model",
                            "Orientation");
            for (String attribute : attributes) {
                setIfNotNull(oldExif, newExif, attribute);
            }
            newExif.saveAttributes();
        } catch (Exception ex) {
            DoricLog.e("Error preserving Exif data on selected image: " + ex);
        }
    }

    private static void setIfNotNull(ExifInterface oldExif, ExifInterface newExif, String property) {
        if (oldExif.getAttribute(property) != null) {
            newExif.setAttribute(property, oldExif.getAttribute(property));
        }
    }
}
