#include <iostream>
#include <fstream>
#include <vector>
#include <set>
#include <ctime>
#include <cstdlib>
#include <algorithm>

using namespace std;

int pos(int y, int x) {
  return y * 256 + x;
}

struct Sprite {
  int y, x;
  int pattern[16][16];
  int color[16];
};

struct SpriteCover {
  SpriteCover(const vector<uint8_t>& city1, const vector<uint8_t>& city2,
              int scroll1_, int scroll2_, int start_, int size_)
      : city1_(city1), city2_(city2), scroll1(scroll1_), scroll2(scroll2_),
        start(start_), size(size_),
        mask(size, vector<bool>(256, false)) {
  }
  int city1(int y, int x) {
    return city1_[y * 256 + x];
  }
  int city2(int y, int x) {
    return city2_[(y + 38) * 256 + x];
  }
  pair<bool, pair<int, int>> find_uncovered_pixel() {
    for (int j = start; j < start + size; j++) {
      for (int i = 0; i < 256; i++) {
        if (city1(scroll1 + j, i) != 0 &&
            city2(j - scroll2, i) == 0 &&
            !mask[j - start][i]) {
          return make_pair(true, make_pair(j, i));
        }
      }
    }
    return make_pair(false, make_pair(0, 0));
  }
  void dump() {
    auto f = fopen("dump.data", "wb");
    for (int j = 0; j < scroll2; j++) {
      for (int i = 0; i < 256; i++) {
        fputc(city1(j + scroll1, i), f);
      }
    }
    for (int j = scroll2; j < 192; j++) {
      for (int i = 0; i < 256; i++) {
        if (city2(j - scroll2, i) == 0) {
          fputc(city1(j + scroll1, i), f);
        } else {
          fputc(city2(j - scroll2, i), f);
        }
      }
    }
    fclose(f);
  }
  Sprite get_sprite(int y, int x) {
    Sprite sprite;
    sprite.x = x;
    sprite.y = y - 1;
    cout << "x " << x << " y " << y << "\n";
    for (int j = y; j < y + 16; j++) {
      int color = 0;
      for (int i = 0; i < 16; i++) {
        if (city1(scroll1 + j, x + i) != 0 &&
            city2(j - scroll2, x + i) == 0 &&
            !mask[j - start][x + i]) {
          color = city1(scroll1 + j, x + i);
          break;
        } 
      }
      cout << "line " << j - y << " color " << color << "\n";
      if (color == 0) {
        continue;
      }
      sprite.color[j - y] = color;
      for (int i = 0; i < 16; i++) {
        if (city1(scroll1 + j, x + i) == color &&
            city2(j - scroll2, x + i) == 0 &&
            !mask[j - start][x + i]) {
          mask[j - start][x + i] = true;
          sprite.pattern[j - y][i] = 1;
        } 
      }
    }
    return sprite;
  }
  void solve() {
    vector<Sprite> sprite;
    while (true) {
      auto pos = find_uncovered_pixel();
      if (!pos.first) break;
      if (sprite.size() == 32) {
        cout << "Abort: too many sprites\n";
        break;
      }
      sprite.push_back(get_sprite(pos.second.first, pos.second.second));
    }
  }
  const vector<uint8_t>& city1_, city2_;
  int scroll1, scroll2, start, size;
  vector<vector<bool>> mask;
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
  SpriteCover cover(city1, city2, 0, 116, 116, 32);
  //cover.solve();
  cover.dump();
  return 0;
}
