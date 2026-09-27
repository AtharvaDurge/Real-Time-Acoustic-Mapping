# Real-Time 2D Acoustic Dark-Vision Mapping Using DSP

A MATLAB + Unity based acoustic sensing and mapping system that
detects obstacles in a visually dark environment using acoustic
echoes and digital signal processing.

## Project Overview

The system simulates a robot operating in a dark environment where
traditional vision-based sensing is unavailable.

The robot sends acoustic chirps in different directions. Echoes
from nearby obstacles are processed using DSP techniques to estimate
the distance of the obstacle.

The estimated angle-distance measurements are then used to construct
a 2D acoustic map in Unity.

## DSP Techniques

- Digital Sampling
- Chirp / LFM Signal Generation
- Hann Windowing
- FFT-Based Frequency Analysis
- Noise Modeling
- Matched Filtering
- Convolution
- Peak Detection
- Time-of-Flight Estimation
- Distance Estimation
- Angular Scanning
- 2D Spatial Mapping

## System Pipeline

Chirp Generation
        ↓
Acoustic Propagation
        ↓
Echo + Noise
        ↓
FFT / Frequency Analysis
        ↓
Matched Filtering
        ↓
Peak Detection
        ↓
Time-of-Flight
        ↓
Distance Estimation
        ↓
Angle + Distance
        ↓
2D Acoustic Map

## Technologies

- MATLAB
- Unity
- C#
- UDP Communication
- Digital Signal Processing

## Applications

- Dark-environment sensing
- Acoustic obstacle detection
- Robotic navigation
- Sonar-inspired sensing
- Indoor environment mapping
