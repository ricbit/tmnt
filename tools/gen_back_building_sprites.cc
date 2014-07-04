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
      : city1_(city1), city2_(city2),
        color(32, vector<vector<Variable>>(16)), 
        ysprite(32), xsprite(32), lineused(32) {
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
    // Each line of each sprite has a color.
    for (int j = 0; j < 32; j++) {
      for (int i = 0; i < 16; i++) {
        for (int c = 0; c < 16; c++) {
          color[j][i].push_back(mip.binary_variable(0));
        }
      }
    }
    // Each line may be used by a sprite or not.
    for (int j = 0; j < 32; j++) {
      for (int i = start; i < start + size; i++) {
        lineused[j].push_back(mip.binary_variable(0));
      }
    }
    // Mark lines used by a sprite.
    for (int j = 0; j < 32; j++) {
      for (int k = systart; k <= syend; k++) {
        auto cons = mip.constraint();
        int acc = 0;
        for (int i = start; i < start + size; i++) {
          int y = i - k;
          if (y >= 0 && y < 16) {
            cons.add_variable(lineused[j][i - start], 1);
            acc++;
          }
        }
        cons.add_variable(ysprite[j][k - systart], -acc);
        cons.commit(0, 16);
      }
    }
    // No more than 8 sprites per line.
    for (int i = start; i < start + size; i++) {
      auto cons = mip.constraint();
      for (int j = 0; j < 32; j++) {
        cons.add_variable(lineused[j][i - start], 1);
      }
      cons.commit(0, 8);
    }
    // Force all sprites to be used.
    /*for (int j = 0; j < 16; j++) {
      auto cons = mip.constraint();
      cons.add_variable(used[j], 1);
      cons.commit(1, 1);
    }*/
    // Break symmetry by ordering sprites by sprite number.
    for (int i = 1 ; i < 32; i++) {
      auto cons = mip.constraint();
      for (int j = 0; j < i; j++) {
        cons.add_variable(used[j], 1);
      }
      cons.add_variable(used[i], -i);
      cons.commit(0, 32);
    }
    // Break symmetry by ordering sprites by y position.
    for (int i = 0 ; i < 32 - 1; i++) {
      for (int j = systart; j <= syend - 1; j++) {
        auto cons = mip.constraint();
        int acc = 0;
        for (int k = i + 1; k < 32; k++) {
          for (int jj = systart + 1; jj <= syend; jj++) {
            cons.add_variable(ysprite[k][jj - systart], 1);
            acc++;
          }
        }
        cons.add_variable(ysprite[i][j - systart], acc);
        cons.commit(0, acc);
      }
    }
    // If used, each line of each sprite has only one color.
    for (int j = 0; j < 32; j++) {
      for (int i = 0; i < 16; i++) {
        auto cons = mip.constraint();
        for (int c = 0; c < 16; c++) {
          cons.add_variable(color[j][i][c], 1);
        }
        cons.add_variable(used[j], -1);
        cons.commit(0, 0);
      }
    }
    // If used, each sprite must have only one Y position.
    for (int j = 0; j < 32; j++) {
      auto cons = mip.constraint();
      for (int i = systart; i <= syend; i++) {
        cons.add_variable(ysprite[j][i - systart], 1);
      }
      cons.add_variable(used[j], -1);
      cons.commit(0, 0);
    } 
    // If used, each sprite must have only one X position.
    for (int j = 0; j < 32; j++) {
      auto cons = mip.constraint();
      for (int i = sxstart; i <= sxend; i++) {
        cons.add_variable(xsprite[j][i - sxstart], 1);
      }
      cons.add_variable(used[j], -1);
      cons.commit(0, 0);
    } 
    return mip.solve();
  }
  MIPSolver mip;
  const vector<uint8_t>& city1_, city2_;
  vector<vector<vector<Variable>>> color;
  vector<vector<Variable>> ysprite, xsprite, lineused;
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
