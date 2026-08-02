# 3D SCARA Pick & Place Simulator (MATLAB)

An interactive, high-fidelity 3D SCARA (Selective Compliance Assembly Robot Arm) Pick-and-Place Simulator built natively in MATLAB.

![MATLAB Version](https://img.shields.io/badge/MATLAB-R2019b%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 📌 Features

- **Base-Lift 3D Kinematics**: Implements a 3D SCARA configuration where the $Z$-axis translation occurs at the base column (Joint 1 lift), maintaining planar rotation for arms $L_1$ and $L_2$.
- **Analytical Inverse Kinematics (IK)**: Resolves joint configurations ($\theta_1, \theta_2, Z$) for target end-effector coordinates $(X, Y, Z)$ using geometric decoupling with elbow-up priority.
- **Interactive UI**: Custom dark-themed App Designer interface built with `uifigure` and `uiaxes`. Includes initial/final target position sliders, numeric edit fields, and animation triggers.
- **Dynamic 3D Camera Gizmo**: Top-right locked orientation triad axes that continuously sync with the main camera rotation in real time without being affected by pan or zoom.
- **High-Fidelity Visuals**: Rounded 3D block arms, cylindrical base pedestal, cyan/orange/white joint caps, translucent ghost arm visualization for final targets, and a 3D workspace cage mesh.
- **Resizable Window**: Fully responsive GUI layout with dynamic reflow upon window resize or maximization.

---

## 📐 DH Parameters & Kinematics Model

| Link $i$ | $\alpha_{i-1}$ | $a_{i-1}$ | $d_i$ | $\theta_i$ |
| :---: | :---: | :---: | :---: | :---: |
| **1** | $0^\circ$ | $0$ | $d_1 = Z$ | $\theta_1^*$ (Prismatic + Revolute Base) |
| **2** | $0^\circ$ | $L_1 = 300\text{ mm}$ | $0$ | $\theta_2^*$ (Revolute Elbow) |
| **3** | $0^\circ$ | $L_2 = 200\text{ mm}$ | $0$ | $0^\circ$ (End Effector) |

### Workspace Limits
- **Outer Radius ($R_{\text{max}}$)**: $L_1 + L_2 = 500\text{ mm}$
- **Inner Radius ($R_{\text{min}}$)**: $|L_1 - L_2| = 100\text{ mm}$
- **$Z$-Travel**: $0\text{ mm} \to 400\text{ mm}$

---

## 🚀 Quick Start

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

## 📂 Project Structure

```
Simulation3D_SCARA/
├── 3DSim/
│   ├── Scara3dApp.m           # Main 3D App UI & 3D OpenGL Rendering Engine
│   ├── scara3d_kinematics.m    # 3D Entry script and CLI argument parser
│   ├── ik3d_solve.m           # 3D Inverse Kinematics solver
│   ├── fk3d_solve.m           # 3D Forward Kinematics solver
│   ├── best_solution_3d.m     # Solution selection (Elbow-Up priority)
│   └── is_reachable_3d.m      # 3D Annular Workspace reachability validator
├── matlab/
│   ├── ScaraPickPlaceApp.m    # 2D App UI
│   ├── scara_kinematics.m     # 2D Entry script
│   ├── ik_solve.m             # 2D Inverse Kinematics solver
│   ├── fk_solve_pos.m         # 2D Forward Kinematics solver
│   ├── plot_workspace.m       # 2D Workspace reachability heatmap generator
│   └── demo_grid.m            # 7-target IK test grid demonstrator
└── .gitignore                 # MATLAB & OS Git ignore configuration
```

---

## 👤 Author

Developed by **Soumashis Dasgupta**.
