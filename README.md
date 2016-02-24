# Coded Time of Flight Imaging System

##Motivation
Depth accuracy has always been an issue with range imaging technologies. Conventional continuous wave time of flight imaging technologies face multipath, scattering and reflection artifacts. Ultrafast imaging got fascinating ever since Doc Edgerton synchronized his electronic stroboscope with a special high-speed motion-picture-camera so that with each flash, exactly one frame of film was exposed. Visualizing and capturing action at speeds beyond human perception will help us in studying a lot of physical phenomenon like scattering, reflection, and interaction with matter. Here we propose a coded time of flight imaging technique to capture light in motion and to ameliorate depth accuuracy.

##Idea
To address the above mentioned issues, we constructed a coded time of flight camera using the PMD 19k-S3 sensor. This involved design of cyclone IV FPGA, soft core processor programming & optical system development. We carefully chose a broadband code instead of a continuous wave to modulate image sensor and light source. A detailed instrumental manual to build your own coded time of flight camera can be found at the end of this page.

##Approach
We exploited the concept of time resolved imaging to capture light in motion. A phase modulated light source locked with image sensor served this purpose. To address the issue of depth accuracy as our second intent, we constructed a mathematical model of multi-frequency light source de-multiplexing, wherein multiple light sources running at different frequencies were used to improve depth accuracy. A broadband signal, accommodating all the bins from multiple light sources was used to modulate the image sensor. This method proved to be more economical and efficient than current models where multiple cameras are used to serve the same purpose.

## HOW TO
Please use the diy_tof.pdf file to find all the necessary information about rebuilding the system from scratch.
