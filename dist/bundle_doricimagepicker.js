'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

exports.ImageSource = void 0;
(function (ImageSource) {
    ImageSource[ImageSource["Gallery"] = 0] = "Gallery";
    ImageSource[ImageSource["Camera"] = 1] = "Camera";
})(exports.ImageSource || (exports.ImageSource = {}));
function imagePicker(context) {
    return {
        pickImage: (params) => {
            return context.callNative("imagePicker", "pickImage", params);
        },
        pickVideo: (params) => {
            return context.callNative("imagePicker", "pickVideo", params);
        },
        pickMultiImage: (params) => {
            return context.callNative("imagePicker", "pickMultiImage", params);
        },
        pickMultiVideo: (params) => {
            return context.callNative("imagePicker", "pickMultiVideo", params);
        },
    };
}

exports.imagePicker = imagePicker;
//# sourceMappingURL=bundle_doricimagepicker.js.map
