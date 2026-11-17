"""Gera o dataset sintetico (CSV) em ./data de forma deterministica.

Cada usuario tem 1-2 generos preferidos (80% das interacoes) e 20% de
exploracao em outros generos. Isso cria comunidades de gosto reais, o que
permite validar que a filtragem colaborativa recomenda algo coerente.

Uso: python scripts/generate_dataset.py
"""
import csv
import random
from datetime import date, timedelta
from pathlib import Path

SEED = 42
N_USERS, N_ARTISTS, SONGS_PER_ARTIST = 50, 30, (5, 8)
DATA = Path(__file__).resolve().parent.parent / "data"

GENRES = ["Rock", "Pop", "Hip Hop", "Jazz", "Eletronica", "MPB",
          "Sertanejo", "Reggae", "Classica", "Metal"]
COUNTRIES = ["BR", "US", "UK", "PT", "AR", "DE"]
FIRST = ["Ana", "Bruno", "Carla", "Diego", "Elisa", "Felipe", "Giovana", "Hugo",
         "Isabela", "Joao", "Karina", "Lucas", "Marina", "Nicolas", "Olivia",
         "Pedro", "Quenia", "Rafael", "Sofia", "Tiago", "Ursula", "Vitor",
         "Wanda", "Xavier", "Yara", "Zeca"]
LAST = ["Silva", "Souza", "Costa", "Lima", "Alves", "Rocha", "Dias", "Melo"]
A_PRE = ["Neon", "Velvet", "Solar", "Atlas", "Cobalt", "Ember", "Lunar", "Onyx",
         "Rustic", "Cosmic", "Silent", "Golden"]
A_SUF = ["Wolves", "Echo", "Parade", "Collective", "Theory", "Station", "Riders",
         "Garden", "Signal", "Harbor"]
S_ADJ = ["Midnight", "Broken", "Electric", "Faded", "Wild", "Quiet", "Burning",
         "Distant", "Golden", "Hollow", "Endless", "Paper"]
S_NOUN = ["Highway", "Dreams", "Rain", "Fire", "Heart", "City", "Waves", "Light",
          "Shadows", "River", "Season", "Memory"]
S_TAIL = ["Tonight", "Forever", "Again", "Blues", "Story", "Road", "Sky", "Song"]


def write(name, header, rows):
    with open(DATA / name, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{name}: {len(rows)} linhas")


def rand_date(rng, start=date(2024, 1, 1), days=700):
    return (start + timedelta(days=rng.randrange(days))).isoformat()


def unique_names(rng, n, make):
    names = set()
    while len(names) < n:
        names.add(make())
    return sorted(names)


def main():
    rng = random.Random(SEED)
    DATA.mkdir(exist_ok=True)

    genres = [(i + 1, g) for i, g in enumerate(GENRES)]
    write("genres.csv", ["id", "name"], genres)

    names = unique_names(rng, N_ARTISTS, lambda: f"{rng.choice(A_PRE)} {rng.choice(A_SUF)}")
    artists = [(i + 1, n, rng.choice(COUNTRIES)) for i, n in enumerate(names)]
    write("artists.csv", ["id", "name", "country"], artists)

    # Cada artista tem um genero principal; musicas herdam o genero do artista
    artist_genre = {a[0]: genres[(a[0] - 1) % len(genres)][0] for a in artists}
    songs, used_titles = [], set()
    for a_id, _, _ in artists:
        for _ in range(rng.randint(*SONGS_PER_ARTIST)):
            while True:
                title = f"{rng.choice(S_ADJ)} {rng.choice(S_NOUN)} {rng.choice(S_TAIL)}"
                if title not in used_titles:
                    used_titles.add(title)
                    break
            songs.append((len(songs) + 1, title, a_id, artist_genre[a_id],
                          rng.randint(1995, 2025), rng.randint(150, 330)))
    write("songs.csv", ["id", "title", "artist_id", "genre_id", "year", "duration_sec"], songs)

    users = [(i + 1, f"{rng.choice(FIRST)} {rng.choice(LAST)}", rng.choice(COUNTRIES),
              rng.randint(16, 65)) for i in range(N_USERS)]
    write("users.csv", ["id", "name", "country", "age"], users)

    by_genre = {}
    for s in songs:
        by_genre.setdefault(s[3], []).append(s)

    listened, likes, follows = [], [], []
    for u_id, *_ in users:
        favs = rng.sample([g[0] for g in genres], rng.randint(1, 2))
        heard = set()
        for _ in range(rng.randint(15, 35)):
            g = rng.choice(favs) if rng.random() < 0.8 else rng.choice(genres)[0]
            heard.add(rng.choice(by_genre[g])[0])
        for s_id in sorted(heard):
            listened.append((u_id, s_id, rng.randint(1, 40), rand_date(rng)))
            if rng.random() < 0.35:
                likes.append((u_id, s_id, rand_date(rng)))
        # Segue artistas dos generos preferidos
        fav_artists = [a for a in artists if artist_genre[a[0]] in favs]
        for a in rng.sample(fav_artists, min(len(fav_artists), rng.randint(1, 4))):
            follows.append((u_id, a[0], rand_date(rng)))

    write("listened.csv", ["user_id", "song_id", "play_count", "last_played"], listened)
    write("likes.csv", ["user_id", "song_id", "liked_at"], likes)
    write("follows.csv", ["user_id", "artist_id", "since"], follows)


if __name__ == "__main__":
    main()
