
-- (Slide 1) --

# Motivation 1: Automated parameter calibration for climate simulations

SpeedyWeather's simple sea ice model with 2 parameters
- freeze rate $f$
- melt rate $m$
- plus parameters from air-ocean, air-ice, ocean-ice fluxes, albedo, snow, ...

So we *need* to calibrate them all together!

https://github.com/user-attachments/assets/835a10a6-a008-4a7c-944a-35d255ccdd46

(Zonal velocity (green), sea ice cover (blue-purple), 150km resolution, Nov-April)

Compared to observations 

<img width="1017" height="754" alt="image" src="https://github.com/user-attachments/assets/02d5c67e-6573-4d9e-b37f-3bfa77fccd60" />

- ❌ Arctic is ice-free in summer
- ❌ Sea ice reaches Scotland in winter

-- (Slide 2) --

# Motivation 2: Calibrate ocean mixing from high-resolution simulations

(Credits to Gregory L Wagner)

Oceananigans can use a high-resolution (but local area) version of itself
to calibrate turbulent kinetic energy for its global simulations

(insert CaTKE figure here)

Possible to do this gradient-free (e.g. Ensemble Kalman Inversion) for
few parameters but likely needs recalibration in every coupled simulation ... 


-- (Slide 3) --

# Motivation 3: Learning the missing physics 

Add a neural network to learn a correction term to known physics
(here more certain dynamics vs less certain physics parameterizations)

NeuralGCM (Kochkov et al. 2024) using Python+JAX

<img width="1677" height="791" alt="image" src="https://github.com/user-attachments/assets/5d446fac-3e95-433b-93a6-07c0f767ac48" />

Required a full JAX rewrite and was very expensive to train (weeks on TPU clusters, $500k)
but allowed to learn missing physics for weather forecasting

<img width="1084" height="516" alt="image" src="https://github.com/user-attachments/assets/38e3930f-04d1-4a4f-8f50-8f1568639d00" />

