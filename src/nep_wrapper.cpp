#include "nepcpu/nep.h"
#include <vector>
#include <string>
#include <cstring>
#include <iostream>

extern "C" {
    void* nep_new(const char* filename, int len) {
        std::string s(filename, len);
        // Trim trailing nulls or spaces if any (Fortran strings...)
        size_t last = s.find_last_not_of(' ');
        if (last != std::string::npos) s = s.substr(0, last + 1);
        
        // Remove null terminator if it was included in len
        if (!s.empty() && s.back() == '\0') s.pop_back();

        try {
            return new NEP(s);
        } catch (const std::exception& e) {
            std::cerr << "Error initializing NEP: " << e.what() << std::endl;
            return nullptr;
        }
    }

    void nep_delete(void* ptr) {
        if (ptr) delete static_cast<NEP*>(ptr);
    }

    void nep_compute(void* ptr, int n_atoms, int* type, double* box, double* position, 
                     double* potential, double* force, double* virial) {
        NEP* nep = static_cast<NEP*>(ptr);
        if (!nep) return;
        
        std::vector<int> type_vec(type, type + n_atoms);
        std::vector<double> box_vec(box, box + 9);
        std::vector<double> pos_vec(position, position + 3 * n_atoms);
        
        std::vector<double> pot_vec(n_atoms);
        std::vector<double> force_vec(3 * n_atoms);
        std::vector<double> virial_vec(9 * n_atoms);

        nep->compute(type_vec, box_vec, pos_vec, pot_vec, force_vec, virial_vec);

        for (int i = 0; i < n_atoms; ++i) potential[i] = pot_vec[i];
        for (int i = 0; i < 3 * n_atoms; ++i) force[i] = force_vec[i];
        for (int i = 0; i < 9 * n_atoms; ++i) virial[i] = virial_vec[i];
    }
}
