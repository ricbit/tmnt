#include <iostream>
#include <vector>
#include <cstdlib>
#include <algorithm>
#include <tuple>

using namespace std;

int pos(int y, int x) {
  return y * 256 + x;
}

struct Sprite {
  Sprite() : y(0), x(0), pattern(16, vector<int>(16, 0)), 
             bitpattern(32), color(16) {}
  int y, x;
  vector<vector<int>> pattern;
  vector<int> bitpattern;
  vector<int> color;
};

struct SpriteCover {
  SpriteCover(const vector<uint8_t>& city1, const vector<uint8_t>& city2,
              const vector<uint8_t>& cityline_,
              int scroll1_, int scroll2_, int split_, int start_, int size_,
              int frame_number_, int palette)
      : city1_(city1), city2_(city2), cityline(cityline_),
        scroll1(scroll1_), scroll2(scroll2_), split(split_ + 1), 
        start(start_), size(size_), frame_number(frame_number_),
        mask(size, vector<bool>(256, false)),
        colormap(16) {
    iota(colormap.begin(), colormap.end(), 0);
    if (palette == 0) {
      colormap[13] = 8;
      colormap[14] = 1;
      colormap[15] = 0;
    } else if (palette == 1) {
      colormap[13] = 8;
      colormap[14] = 11;
      colormap[15] = 8;
    } else {
      colormap[13] = 11;
      colormap[14] = 11;
      colormap[15] = 6;
    }
  }
  int city1(int y, int x) {
    return y < 212 && y >= 0 ? city1_[y * 256 + x] : 0;
  }
  int city2(int y, int x) {
    return city2_[(y + 70) * 256 + x];
  }
  pair<bool, pair<int, int>> find_uncovered_pixel() {
    for (int j = start; j < start + size; j++) {
      for (int i = 0; i < 256; i++) {
        if (city2(j, i) == 0 &&
            city1(split + j, i) != colormap[cityline[i]] &&
            !mask[j - start][i]) {
          return make_pair(true, make_pair(j, i));
        }
      }
    }
    return make_pair(false, make_pair(0, 0));
  }
  void dump() {
    auto f = fopen("dump.data", "wb");
    for (int j = 0; j < split - scroll1; j++) {
      for (int i = 0; i < 256; i++) {
        fputc(city1(j + scroll1, i), f);
      }
    }
    for (int j = split - scroll1; j < 192; j++) {
      for (int i = 0; i < 256; i++) {
        int ycity2 = j - split + scroll1;
        if (city2(ycity2, i) == 0) {
          fputc(city1(j + scroll1, i), f);
        } else {
          fputc(city2(ycity2, i), f);
        }
      }
    }
    fclose(f);
  }
  void dump_sprites() {
    auto f = fopen("sprite.data", "wb");
    int back = 0;
    for (auto s : sprite) {
      for (int j = 0; j < 16; j++) {
        for (int i = 0; i < 16; i++) {
          fputc(s.pattern[j][i] > 0 ? 255 : back, f);
        }
      }
      back ^= 50;
    }
    fclose(f);
  }
  Sprite get_sprite(int y, int x) {
    Sprite sprite;
    sprite.x = x;
    sprite.y = y;
    int limit = min(start + size, y + 16);
    for (int j = y; j < limit; j++) {
      int color = 0;
      for (int i = 0; i < min(16, 255 - x); i++) {
        if (city2(j, x + i) == 0 &&
            city1(split + j, x + i) != colormap[cityline[x + i]] &&
            !mask[j - start][x + i]) {
          color = city1(split + j, x + i);
          break;
        } 
      }
      if (color == 0) {
        continue;
      }
      sprite.color[j - y] = color;
      for (int i = 0; i < 16; i++) {
        if (city1(split + j, x + i) == color &&
            city2(j, x + i) == 0 &&
            !mask[j - start][x + i]) {
          mask[j - start][x + i] = true;
          sprite.pattern[j - y][i] = 1;
        } 
      }
    }
    // Create bit pattern.
    int index = 0;
    for (int ii = 0; ii < 2; ii++) {
      for (int j = 0; j < 16; j++) {
        int patt = 0;
        for (int i = 0; i < 8; i++) {
          patt |= sprite.pattern[j][ii * 8 + i] << (7 - i);
        }
        sprite.bitpattern[index++] = patt;
      }
    }
    return sprite;
  }
  bool solve() {
    while (true) {
      auto pos = find_uncovered_pixel();
      if (!pos.first) break;
      if (sprite.size() == 32) {
        //cout << "Abort: too many sprites\n";
        return false;
      }
      sprite.push_back(get_sprite(pos.second.first, pos.second.second));
    }
    vector<int> lines(192, 0);
    for (auto s : sprite) {
      for (int i = 0; i < 16; i++) {
        if (s.y + i < 192) {
          lines[s.y + i]++;
          if (lines[s.y + i] > 8 &&
              (s.bitpattern[i] || s.bitpattern[i + 16])) {
            //cout << "More than 8 sprites per line\n";
            /*if (frame_number == 10) {
              dump_sprites();
              for (int i = 0; i < int(sprite.size()); i++) {
                cout << i << " : " << sprite[i].y << "\n";
              }
              exit(0);
            }*/
            return false;
          }
        }
      }
    }
    return true;
  }
  const vector<uint8_t>& city1_, city2_, cityline;
  int scroll1, scroll2, split, start, size, frame_number;
  vector<vector<bool>> mask;
  vector<Sprite> sprite;
  vector<int> colormap;
};

vector<uint8_t> read_raw(string file, int lines) {
  auto f = fopen(file.c_str(), "rb");
  vector<uint8_t> raw(lines * 256);
  fread(raw.data(), 1, lines * 256, f);
  fclose(f);
  return raw;
}

pair<int, SpriteCover> find_cover(
    const vector<uint8_t>& city1, const vector<uint8_t>& city2,
    const vector<uint8_t>& cityline,
    int scroll1, int scroll2, int split, int frame_number) {
  for (int i = 0; i < 192; i++) {
    int limit = min(86, 192 - (split - scroll1 + i));
    int bestp = -1, bestsize = 100;
    for (int p = 0; p < 3; p++) {
      SpriteCover cover(
          city1, city2, cityline, scroll1, scroll2, 
          split, i, limit, frame_number, p);
      if (cover.solve() && int(cover.sprite.size()) < bestsize) {
        bestp = p;
        bestsize = cover.sprite.size();
      }
    }
    if (bestp >= 0) {
      SpriteCover cover(
          city1, city2, cityline, scroll1, scroll2, 
          split, i, limit, frame_number, bestp);
      cover.solve();
      cout << "scroll1: " << scroll1 << " : size " << cover.sprite.size() 
           << " start y : " << i << " palette : " << bestp << "\n";
      return make_pair(bestp, cover);
    }
  }
  return make_pair(
      -1, SpriteCover(city1, city2, cityline, 0, 197, 139, 192, 0, 0, 0));
}

struct SpriteBlock {
  vector<vector<int>> patterns;
  int find_sprite(const Sprite& s) {
    for (int i = 0; i < int(patterns.size()); i++) {
      if (s.bitpattern == patterns[i]) {
        return i;
      }
    }
    return -1;
  }
  bool check(const SpriteCover& cover) {
    int not_found = 0;
    for (const auto s : cover.sprite) {
      if (find_sprite(s) < 0) {
        not_found++;
      }
    }
    return patterns.size() + not_found <= 64;
  }
  vector<int> insert(const SpriteCover& cover) {
    vector<int> answer;
    for (const auto s : cover.sprite) {
      int index = find_sprite(s);
      if (index < 0) {
        patterns.push_back(s.bitpattern);
        index = patterns.size() - 1;
      }
      answer.push_back(index);
    }
    return answer;
  }
};

template<typename T>
pair<vector<int>, vector<int>> get_attr(T a) {
  vector<int> colors, attr;
  for (const auto& s : get<2>(a).sprite) {
    for (int color : s.color) {
      colors.push_back(color);
    }
  }
  for (int i = 0; i < int(get<1>(a).size()); i++) {
    attr.push_back((get<2>(a).sprite[i].y + 255 + 256 - 51) % 256);
    attr.push_back(get<2>(a).sprite[i].x);
    attr.push_back(get<1>(a)[i] * 4);
    attr.push_back(0);
  }
  if (get<2>(a).sprite.size() < 32) {
    attr.push_back(0xD8);
  }
  return make_pair(colors, attr);
}

vector<int> compress(const vector<int>& stream) {
  int size = stream.size();
  int pos = 0;
  vector<int> ans;
  while (size) {
    int s = min(127, size);
    ans.push_back(s);
    for (int i = 0; i < s; i++) {
      ans.push_back(stream[pos + i]);
    }
    pos += s;
    size -= s;
  }
  ans.push_back(0);
  return ans;
}

template<typename T>
void save_patterns(T block) {
  auto f = fopen("back_building_patt.sc5", "wb");
  for (const auto& b : block) {
    cout << "block size " << b->patterns.size() << "\n";
    for (const auto& patt : b->patterns) {
      for (int p : patt) {
        fputc(p, f);
      }
    }
    for (int i = 0; i < int(64 - b->patterns.size()) * 32; i++) {
      fputc(0, f);
    }
    delete b;
  }
  fclose(f);
}

template<typename T>
void save_attr(T attr) {
  auto f = fopen("back_building_attr.z5", "wb");
  auto f2 = fopen("back_building_size.bin", "wb");
  vector<int> attr_size;
  for (const auto& a : attr) {
    auto contents = get_attr(a);
    vector<int> compressed = compress(contents.first);
    int size = compressed.size();
    for (int i : compressed) {
      fputc(i, f);
    }
    fputc(size % 256, f2);
    fputc(size / 256, f2);
    vector<int> compressed_attr = compress(contents.second);
    size = compressed_attr.size();
    for (int i : compressed_attr) {
      fputc(i, f);
    }
    fputc(size % 256, f2);
    fputc(size / 256, f2);
  }
  fclose(f);
  fclose(f2);
  f = fopen("back_building_patt_base.bin", "wb");
  for (const auto& a : attr) {
    fputc((0x6000 + 0x800 * get<0>(a)) >> 11, f);
  }
  fclose(f);
  f = fopen("back_building_palette.bin", "wb");
  for (const auto& a : attr) {
    fputc(3 * get<3>(a), f);
  }
  fclose(f);
}

int main() {
  auto city1 = read_raw("raw/city1.raw", 212);
  auto city2 = read_raw("raw/city2.raw", 606);
  auto cityline = read_raw("raw/cityline.raw", 1);
  vector<SpriteBlock*> block;
  vector<tuple<int, vector<int>, SpriteCover, int>> attr;
  block.push_back(new SpriteBlock());
  for (int i = 1; i <= 26; i++) {
    cout << "Frame " << i << " (" << (833 + i) << ") ";
    auto cover_pair = find_cover(
        city1, city2, cityline, i * 2, 9 + i * 10, 195 - i * 8, i);
    SpriteBlock* last = *block.rbegin();
    if (!last->check(cover_pair.second)) {
      block.push_back(new SpriteBlock());
      last = *block.rbegin();
    }
    int block_number = block.size() - 1;
    auto patt = last->insert(cover_pair.second);
    attr.push_back(
        make_tuple(block_number, patt, cover_pair.second, cover_pair.first));
  }
  save_patterns(block);
  save_attr(attr);
  return 0;
}
