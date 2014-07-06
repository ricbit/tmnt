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
              const vector<uint8_t>& cityline_,
              int scroll1_, int scroll2_, int start_, int size_)
      : city1_(city1), city2_(city2), cityline(cityline_),
        scroll1(scroll1_), scroll2(scroll2_),
        start(start_), size(size_),
        mask(size, vector<bool>(256, false)) {
  }
  int city1(int y, int x) {
    return y < 190 ? city1_[y * 256 + x] : 0;
  }
  int city2(int y, int x) {
    return city2_[(y + 38) * 256 + x];
  }
  pair<bool, pair<int, int>> find_uncovered_pixel() {
    for (int j = start; j < start + size; j++) {
      for (int i = 0; i < 256; i++) {
        if (city1(scroll1 + j, i) != 0 &&
            city2(j - scroll2, i) == 0 &&
            city1(scroll1 + j, i) != cityline[i] &&
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
    sprite.y = y;
    for (int i = 0; i < 16; i++) {
      for (int j = 0; j < 16; j++) {
        sprite.pattern[i][j] = 0;
      }
    }
    cout << "x " << x << " y " << y << "\n";
    for (int j = y; j < min(start + size, y + 16); j++) {
      int color = 0;
      for (int i = 0; i < min(16, 255 - x); i++) {
        if (city1(scroll1 + j, x + i) != 0 &&
            city2(j - scroll2, x + i) == 0 &&
            city1(scroll1 + j, x + i) != cityline[x + i] &&
            !mask[j - start][x + i]) {
          color = city1(scroll1 + j, x + i);
          break;
        } 
      }
      //cout << "line " << j - y << " color " << color << "\n";
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
    while (true) {
      auto pos = find_uncovered_pixel();
      if (!pos.first) break;
      if (sprite.size() == 32) {
        cout << "Abort: too many sprites\n";
        break;
      }
      sprite.push_back(get_sprite(pos.second.first, pos.second.second));
    }
    vector<int> lines(192, 0);
    for (auto s : sprite) {
      for (int i = 0; i < 16; i++) {
        if (s.y + i < 192) {
          lines[s.y + i]++;
        }
      }
    }
    for (int i : lines) {
      if (i > 8) {
        cout << "More than 8 sprites per line\n";
        break;
      }
    }
  }
  void write() {
    auto f = fopen("back_building_patt.sc5", "wb");
    for (int s = 0; s < 32; s++) {
      for (int ii = 0; ii < 2; ii++) {
        for (int j = 0; j < 16; j++) {
          int patt = 0;
          for (int i = 0; i < 8; i++) {
            patt |= sprite[s].pattern[j][ii * 8 + i] << (7 - i);
          }
          fputc(patt, f);
        }
      }
    }
    fclose(f);
    f = fopen("back_building_attr.sc5", "wb");
    for (int i = 0; i < 32; i++) {
      for (int j = 0; j < 16; j++) {
        fputc(sprite[i].color[j], f);
      }
    }
    for (int i = 0; i < 32; i++) {
      fputc((sprite[i].y + 255 + 256 + 81 - scroll2) % 256, f);
      fputc(sprite[i].x, f);
      fputc(i, f);
      fputc(0, f);
    }
    fclose(f);
  }
  const vector<uint8_t>& city1_, city2_, cityline;
  int scroll1, scroll2, start, size;
  vector<vector<bool>> mask;
  vector<Sprite> sprite;
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
  auto cityline = read_raw("/home/ricbit/work/tmnt/raw/cityline.raw", 1);
  SpriteCover cover(city1, city2, cityline, 0, 116, 145, 64);
  cover.solve();
  cover.write();
  return 0;
}
