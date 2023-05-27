# flutter_sound_processing

Flutter library that provides audio processing capabilities, including the calculation of feature matrices from audio signals. It enables Flutter developers to extract meaningful information from audio data, such as Mel-Frequency Cepstral Coefficients (MFCCs) and spectral features.

**Note: iOS support is currently in progress.**

## Usage

To use this plugin, add `flutter_sound_processing` as a dependency in your `pubspec.yaml` file using command:

`flutter pub add flutter_sound_processing`

## API Reference
`getFeatureMatrix` Calculates the feature matrix based on the provided audio signals and parameters.
* `signals`: A list of double values representing the audio signals.
* `sampleRate`: The sample rate of the audio signals.
* `hopLength`: The hop length (in samples) used for analysis.
* `nMels`: The number of Mel filters to be used in the analysis.
* `fftSize`: The size of the FFT used for spectral analysis.
* `mfcc`: The number of MFCC coefficients to be calculated.
* Returns a Future<Float64List> that resolves to the feature matrix represented as a Float64List, or null if there was an error during the calculation.

## Contributing
Contributions to FlutterSoundProcessing are welcome! If you find a bug or want to add a new feature, please open an issue or submit a pull request on the [GitHub repository](https://github.com/tkas9mbek/flutter_sound_processing).

## License
This project is licensed under the [MIT License](https://github.com/tkas9mbek/flutter_sound_processing/blob/master/LICENSE).
