#include <iostream>
#include <fstream>
#include <vector>
#include <set>
#include <ctime>
#include <cstdlib>
#include <algorithm>
#include "easyscip.h"

using namespace std;
using namespace easyscip;

int pos(int y, int x) {
  return y * 256 + x;
}

struct SpriteCover {
  SpriteCover(const vector<uint8_t>& city1, const vector<uint8_t>& city2) 
      : city1_(city1), city2_(city2) {
  }
  int city1(int y, int x) {
    return city1_[y * 256 + x];
  }
  int city2(int y, int x) {
    return city2_[(y + 38) * 256 + x];
  }
  Solution solve(int scroll1, int scroll2, int start, int size) {
    systart = start - 15;
    syend = start + size - 1;
    xsprite.resize(32);
    ysprite.resize(32);
    pixel.resize(32);
    color.resize(32, vector<vector<Variable>>(16));
    // Y position of each sprite.
    for (int j = 0; j < 32; j++) {
      for (int i = systart; i <= syend; i++) {
        ysprite[j].push_back(mip.binary_variable(0));
      }
    }
    // Find xstart and xend.
    int xstart = 255;
    int xend = 0;
    for (int j = start; j < start + size; j++) {
      for (int i = 0; i < 256; i++) {
        if (city1(scroll1 + j, i) != 0 &&
            city2(j - scroll2, i) == 0) {
          xstart = min(xstart, i);
          xend = max(xend, i);
        }
      }
    }
    cout << "xstart: " << xstart << "\n";
    cout << "xend: " << xend << "\n";
    sxstart = xstart - 15;
    sxend = xend;
    // X position of each sprite.
    for (int j = 0; j < 32; j++) {
      for (int i = sxstart; i <= sxend; i++) {
        xsprite[j].push_back(mip.binary_variable(0));
      }
    }
    // Each sprite may be used or not.
    for (int j = 0; j < 32; j++) {
      used.push_back(mip.binary_variable(1));
    }
    // Each pixel may be turned on or off.
    for (int j = 0; j < 32; j++) {
      for (int i = 0; i < 256; i++) {
        pixel[j].push_back(mip.binary_variable(0));
      }
    }
    // Each line of each sprite has a color.
    for (int j = 0; j < 32; j++) {
      for (int i = 0; i < 16; i++) {
        for (int c = 0; c < 16; c++) {
          color[j][i].push_back(mip.binary_variable(0));
        }
      }
    }
    // Each line of each sprite has only one color.
    for (int j = 0; j < 32; j++) {
      for (int i = 0; i < 16; i++) {
        auto cons = mip.constraint();
        for (int c = 0; c < 16; c++) {
          cons.add_variable(color[j][i][c], 1);
        }
        cons.commit(1, 1);
      }
    }
    // A sprite is used if any of its pixels are on.
    for (int j = 0; j < 32; j++) {
      auto cons = mip.constraint();
      for (int i = 0; i < 256; i++) {
        cons.add_variable(pixel[j][i], 1);
      }
      cons.add_variable(used[j], -256);
      cons.commit(-255, 0);
    }
    // Each sprite must have only one Y position.
    for (int j = 0; j < 32; j++) {
      auto cons = mip.constraint();
      for (int i = systart; i <= syend; i++) {
        cons.add_variable(ysprite[j][i - systart], 1);
      }
      cons.commit(1, 1);
    } 
    // Each sprite must have only one X position.
    for (int j = 0; j < 32; j++) {
      auto cons = mip.constraint();
      for (int i = sxstart; i <= sxend; i++) {
        cons.add_variable(xsprite[j][i - sxstart], 1);
      }
      cons.commit(1, 1);
    } 
    return mip.solve();
  }
  MIPSolver mip;
  const vector<uint8_t>& city1_, city2_;
  vector<vector<vector<Variable>>> color;
  vector<vector<Variable>> ysprite, xsprite;
  vector<vector<Variable>> pixel;
  vector<Variable> used;
  int systart, syend, sxstart, sxend;
};

vector<uint8_t> read_raw(string file, int lines) {
  auto f = fopen(file.c_str(), "rb");
  vector<uint8_t> raw(lines * 256);
  fread(raw.data(), 1, lines * 256, f);
  fclose(f);
  return raw;
}

int main() {
  auto city1 = read_raw("/home/ricbit/work/tmnt/raw/city1.raw", 190);
  auto city2 = read_raw("/home/ricbit/work/tmnt/raw/city2.raw", 606);
  SpriteCover cover(city1, city2);
  auto sol = cover.solve(0, 116, 116, 32);
  for (int j = 0; j < 32; j++) {
    if (sol.value(cover.used[j]) < 0.5) continue;
    cout << "Sprite " << j << " : ";
    for (int i = cover.systart; i <= cover.syend; i++) {
      if (sol.value(cover.ysprite[j][i - cover.systart]) > 0.5) {
        cout << i << ",";
      }
    }
    for (int i = cover.sxstart; i <= cover.sxend; i++) {
      if (sol.value(cover.xsprite[j][i - cover.sxstart]) > 0.5) {
        cout << i << "\n";
      }
    }
  }
  return 0;
}
