import { BridgeContext } from "doric";

export enum ImageSource {
  Gallery = 0,
  Camera = 1,
}

export interface ImageFile {
  filePath: string;
}

export function imagePicker(context: BridgeContext) {
  return {
    pickImage: (params: {
      source: ImageSource;
      maxWidth?: number;
      maxHeight?: number;
      imageQuality?: number;
    }) => {
      return context.callNative("imagePicker", "pickImage", params) as Promise<
        ImageFile | undefined
      >;
    },
    pickVideo: (params: {
      source: ImageSource;
      cameraDevice?: "front" | "back";
    }) => {
      return context.callNative("imagePicker", "pickVideo", params) as Promise<
        ImageFile | undefined
      >;
    },
    pickMultiImage: (params: {
      source: ImageSource;
      maxWidth?: number;
      maxHeight?: number;
      imageQuality?: number;
    }) => {
      return context.callNative(
        "imagePicker",
        "pickMultiImage",
        params
      ) as Promise<ImageFile[] | undefined>;
    },
    pickMultiVideo: (params: {
      source: ImageSource;
      cameraDevice?: "front" | "back";
    }) => {
      return context.callNative(
        "imagePicker",
        "pickMultiVideo",
        params
      ) as Promise<ImageFile[] | undefined>;
    },
  };
}
