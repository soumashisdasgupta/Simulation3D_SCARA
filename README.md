# 3D SCARA Pick & Place Simulator (MATLAB)

An interactive 3D SCARA (Selective Compliance Assembly Robot Arm) Pick-and-Place Simulator developed in MATLAB.

![MATLAB Version](https://img.shields.io/badge/MATLAB-R2019b%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Project Objective

This project demonstrates analytical forward and inverse kinematics in 3D of a SCARA robot through an interactive MATLAB-based simulation environment.

---

## Features

- **Base-Lift 3D Kinematics**: Implements a 3D SCARA configuration where the $Z$-axis translation occurs at the base column (i.e a prismatic Joint), maintaining planar rotation for arms $L_1$ and $L_2$ (revolute joints).
- **Inverse Kinematics (IK)**: Resolves joint configurations ($\theta_1, \theta_2, Z$) for target end-effector coordinates $(X, Y, Z)$ using an analytical geometric solution with elbow-up priority.
- **Interactive UI**: Custom dark-themed App Designer interface built with `uifigure` and `uiaxes`. Includes intial& final position sliders, numeric input fields, and animation controls for interactive target manipulation.
- **Dynamic Orientaion Indicator in 3D**: Top-right locked orientation triad axes that remains synchronized with the main camera orientation while remaining independent of pan and zoom.
- **3D Visualization**: 3D visualization featuring rounded arm links, cylindrical base, joint markers, translucent ghost-arm preview, and workspace cage mesh.

---

## Requirements

- MATLAB R2019b or newer
- MATLAB App Designer
- OpenGL-compatible graphics hardware (recommended for smooth 3D rendering)

---

## DH Parameters & Kinematics Model

| Link $i$ | $\alpha_{i-1}$ | $a_{i-1}$ | $d_i$ | $\theta_i$ |
| :---: | :---: | :---: | :---: | :---: |
| **1** | $0^\circ$ | $0$ | $d_1 = Z$ | $\theta_1^*$ (Base prismatic lift and revolute joint) |
| **2** | $0^\circ$ | $L_1 = 300\text{ mm}$ | $0$ | $\theta_2^*$ (Revolute Elbow) |
| **3** | $0^\circ$ | $L_2 = 200\text{ mm}$ | $0$ | $0^\circ$ (End Effector) |

### Workspace Limits
- **Outer Radius ($R_{\text{max}}$)**: $L_1 + L_2 = 500\text{ mm}$
- **Inner Radius ($R_{\text{min}}$)**: $|L_1 - L_2| = 100\text{ mm}$
- **$Z$-Travel**: $0\text{ mm} \to 400\text{ mm}$

---

## Quick Start

### 1. Launch 3D Simulator
Navigate to the `3DSim/` directory in MATLAB and run the entry-point script:

```matlab
cd('3DSim')
scara3d_kinematics
```

### 2. Custom Parameters & Initial Targets
You can specify custom link lengths, $Z$-travel bounds, and target positions directly from the command line:

```matlab
scara3d_kinematics L1 320 L2 220 z_min 0 z_max 500 ix 300 iy 100 iz 150 fx 0 fy 350 fz 200
```

### 3. Launch 2D Simulator
The 2D planar version is maintained under the `matlab/` directory:

```matlab
cd('matlab')
scara_kinematics
```

---

## Project Structure

```
Simulation3D_SCARA/
├── 3DSim/
│   ├── Scara3dApp.m           # Main GUI & 3D-visualization
│   ├── scara3d_kinematics.m   # Entry point and argument parser
│   ├── ik3d_solve.m           # 3D Inverse Kinematics solver
│   ├── fk3d_solve.m           # 3D Forward Kinematics solver
│   ├── best_solution_3d.m     # Preferred IK solution selection (Elbow-Up priority)
│   └── is_reachable_3d.m      # Workspace reachability check
├── matlab/
│   ├── ScaraPickPlaceApp.m    # 2D App UI
│   ├── scara_kinematics.m     # 2D Entry script
│   ├── ik_solve.m             # 2D Inverse Kinematics solver
│   ├── fk_solve_pos.m         # 2D Forward Kinematics solver
│   ├── plot_workspace.m       # Workspace visualization
│   └── demo_grid.m            # IK demonstration script
└── .gitignore                 # MATLAB & OS Git ignore configuration
```

## Limitations

- Standard industrial SCARA robots typically include a fourth degree of freedom for end-effector (wrist) rotation about the vertical axis. This simulator omits that joint and models only the three degrees of freedom required for end-effector positioning: two revolute joints ($\theta_1$, $\theta_2$) and one prismatic Z-axis joint.
- Consequently, the simulator computes only the position of the end effector $(X, Y, Z)$ and does not model end-effector orientation.
- Assumes rigid links and ideal joints.
- Collision detection is not included.
- Dynamics and actuator modelling are outside the scope of this simulator.

---

## Future Work

- Collision avoidance
- ROS integration
- Camera-based object detection
- Pick-and-place automation

---

## License

This project is released under the MIT License.

---

## 👤 Author

Developed by **Soumashis Dasgupta**.
