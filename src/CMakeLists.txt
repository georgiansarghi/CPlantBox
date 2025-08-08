# Disable LTO/IPO to avoid toolchain issues in container builds
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION OFF)
#
# 1. Make CPlantBox library
#

include_directories(structural)
include_directories(functional)
include_directories(visualisation)

include_directories(external/tinyxml2)
include_directories(external/eigen) # fetching as git submodule @tag 3.3.7

include_directories(external/) # for PiafMunch

# -----------------------------
# Shared Library
# -----------------------------
set(CPLANTBOX_SOURCES
    structural/organparameter.cpp
    structural/rootparameter.cpp
    structural/seedparameter.cpp
    structural/leafparameter.cpp
    structural/stemparameter.cpp
    structural/Organ.cpp
    structural/Root.cpp
    structural/RootDelay.cpp
    structural/Seed.cpp
    structural/Stem.cpp
    structural/Leaf.cpp
    structural/Plant.cpp
    structural/Organism.cpp
	structural/Plant.cpp            			
    structural/RootSystem.cpp
    structural/MappedOrganism.cpp
    structural/sdf.cpp
    structural/SegmentAnalyser.cpp
    structural/tropism.cpp

    functional/Photosynthesis.cpp
    functional/Perirhizal.cpp
    functional/PlantHydraulicParameters.cpp
    functional/PlantHydraulicModel.cpp

	visualisation/Quaternion.h
	visualisation/CatmullRomSpline.h
	visualisation/PlantVisualiser.h
    visualisation/PlantVisualiser.cpp

    external/tinyxml2/tinyxml2.cpp
    external/aabbcc/AABB.cc
    external/gauss_legendre/gauss_legendre.cpp
)

# Python and pybind11 (modern discovery)
find_package(Python COMPONENTS Interpreter Development.Module Development.Embed REQUIRED)
add_subdirectory(external/pybind11)

pybind11_add_module(plantbox SHARED 
            PyPlantBox.cpp                                  
            )
target_link_libraries(plantbox PUBLIC 
			CPlantBox)
			
set_target_properties(plantbox PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/)

	set_target_properties(CPlantBox PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/)

	target_include_directories(
							CPlantBox
							PUBLIC
							${PROJECT_BINARY_DIR}/src/external/sundials/include
							${PROJECT_BINARY_DIR}/src/external/suitsparse/include
	)
endif()

# Set library output directory
set_target_properties(CPlantBox PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "$ORIGIN"
)

# -----------------------------
# Python binding
# -----------------------------

pybind11_add_module(plantbox PyPlantBox.cpp)
target_link_libraries(plantbox PRIVATE CPlantBox Python3::Module)

set_target_properties(plantbox PROPERTIES
    INSTALL_RPATH "$ORIGIN"
)

# Install plantbox module into Python site-packages
install(TARGETS CPlantBox LIBRARY DESTINATION "${Python3_SITEARCH}/plantbox") 
install(TARGETS plantbox LIBRARY DESTINATION "${Python3_SITEARCH}/plantbox")

install( FILES ${CMAKE_CURRENT_SOURCE_DIR}/__init__.py DESTINATION ${Python3_SITEARCH}/plantbox)

install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/visualisation DESTINATION ${Python3_SITEARCH}/plantbox
		FILES_MATCHING
        PATTERN "*.py"
        PATTERN "__pycache__" EXCLUDE)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/rsml DESTINATION ${Python3_SITEARCH}/plantbox
		FILES_MATCHING
        PATTERN "*.py"
        PATTERN "__pycache__" EXCLUDE)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/structural DESTINATION ${Python3_SITEARCH}/plantbox
		FILES_MATCHING
        PATTERN "*.py"
        PATTERN "__pycache__" EXCLUDE)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/functional DESTINATION ${Python3_SITEARCH}/plantbox
		FILES_MATCHING
        PATTERN "*.py"
        PATTERN "__pycache__" EXCLUDE)

