const {onSchedule} = require("firebase-functions/v2/scheduler");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

setGlobalOptions({region: "us-central1"});

// 初期化がまだ行われていない場合のみ initializeApp を呼び出す
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.updateRanking = onSchedule("0 */2 * * *", async (event) => {
  try {
    // 今日を起点に2週間前の日時を計算
    const twoWeeksAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000);

    // postsコレクションからcreated_timeが2週間以内の投稿を取得
    const postsSnapshot = await db
        .collection("posts")
        .where("created_time", ">", twoWeeksAgo) // 2週間以内の投稿に限定
        .get();

    const currentPostList = postsSnapshot.docs;

    const postPoints = {};

    await Promise.all(
        currentPostList.map(async (postDoc) => {
          const postId = postDoc.id;
          let points = 0;

          const favoriteSnapshot = await db
              .collection("posts")
              .doc(postId)
              .collection("favorite_users")
              .get();

          favoriteSnapshot.docs.forEach((doc) => {
            const addedAt = doc.data().added_at.toDate();
            if (addedAt > new Date(Date.now() - 24 * 60 * 60 * 1000)) {
              points += 3;
            } else if (addedAt > new Date(Date.now() - 72 * 60 * 60 * 1000)) {
              points += 2;
            } else if (addedAt > new Date(Date.now() - 168 * 60 * 60 * 1000)) {
              points += 1;
            }
          });

          const repostSnapshot = await db
              .collection("posts")
              .doc(postId)
              .collection("reposts")
              .get();

          repostSnapshot.docs.forEach((doc) => {
            const timestamp = doc.data().timestamp.toDate();
            if (timestamp > new Date(Date.now() - 24 * 60 * 60 * 1000)) {
              points += 9;
            } else if (timestamp > new Date(Date.now() - 72 * 60 * 60 * 1000)) {
              points += 6;
            } else if (timestamp > new Date(Date.now() - 168 * 60 * 60 * 1000)) {
              points += 3;
            }
          });

          const replySnapshot = await db
              .collection("posts")
              .doc(postId)
              .collection("reply_post")
              .get();

          replySnapshot.docs.forEach((doc) => {
            const timestamp = doc.data().timestamp.toDate();
            if (timestamp > new Date(Date.now() - 24 * 60 * 60 * 1000)) {
              points += 6;
            } else if (timestamp > new Date(Date.now() - 72 * 60 * 60 * 1000)) {
              points += 4;
            } else if (timestamp > new Date(Date.now() - 168 * 60 * 60 * 1000)) {
              points += 2;
            }
          });

          postPoints[postId] = points;
        }),
    );

    const sortedPosts = Object.entries(postPoints).sort((a, b) => b[1] - a[1]);
    const rankingCollection = db.collection("ranking");
    const batch = db.batch();

    const existingRanking = await rankingCollection.get();
    existingRanking.docs.forEach((doc) => batch.delete(doc.ref));

    sortedPosts.slice(0, 200).forEach(([postId, points], index) => {
      const docRef = rankingCollection.doc(postId);
      batch.set(docRef, {
        count: index + 1,
        points: points,
        hide: false,
      });
    });

    await batch.commit();
    console.log("Ranking updated successfully.");
  } catch (error) {
    console.error("Error updating ranking:", error);
  }
});

exports.updateTrends = onSchedule("0 */2 * * *", async (event) => {
  try {
    const thirtySixHoursAgo = new Date(Date.now() - 36 * 60 * 60 * 1000);

    // 過去36時間以内の投稿を取得
    const postsSnapshot = await db
        .collection("posts")
        .where("created_time", ">", thirtySixHoursAgo)
        .get();

    const wordCounts = new Map(); // 単語の出現回数を格納するマップ

    // 投稿のcontentを単語ごとに分割し、カウント
    postsSnapshot.docs.forEach((doc) => {
      const content = doc.data().content || "";
      const words = content
          .split(new RegExp("[^\\p{L}\\p{N}_]+", "u")) // 日本語や特殊文字を含む単語を分割
          .filter((word) => word.length >= 3 && word.length <= 15); // 1文字以上15文字以内の単語のみ

      words.forEach((word) => {
        const lowerWord = word.toLowerCase(); // 小文字に変換して統一

        // 重複回数をカウント
        const currentCount = wordCounts.get(lowerWord) || 0;
        wordCounts.set(lowerWord, currentCount + 1);
      });
    });

    // 頻出単語を取得し、ランキング順にソート
    const sortedWords = Array.from(wordCounts.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 20); // 上位20個を取得

    const trendCollection = db.collection("trend");
    const batch = db.batch();

    // 既存のtrendコレクションをクリア
    const existingTrends = await trendCollection.get();
    existingTrends.docs.forEach((doc) => batch.delete(doc.ref));

    // 新しいトレンドデータを追加
    sortedWords.forEach(([word, count], index) => {
      const docRef = trendCollection.doc(word);
      batch.set(docRef, {
        word: word,
        count: count,
        ranking: index + 1,
        hide: false,
      });
    });

    await batch.commit();
    console.log("Trends updated successfully.");
  } catch (error) {
    console.error("Error updating trends:", error);
  }
});

