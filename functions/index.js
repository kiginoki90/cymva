const {onSchedule} = require("firebase-functions/v2/scheduler");
const {setGlobalOptions} = require("firebase-functions/v2");
const {defineSecret} = require("firebase-functions/params");
const axios = require("axios");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const openAiApiKey = defineSecret("OPENAI_API_KEY");

setGlobalOptions({region: "us-central1"});

initializeApp();
const db = getFirestore();

exports.generateAndAddPost = onSchedule(
    {
      schedule: "0 10 * * *",
      secrets: [openAiApiKey],
    },
    async (event) => {
      try {
        const postsSnapshot = await db
            .collection("posts")
            .where("post_account_id", "==", "c1nvtSQSiSOwCrEKEADK")
            .orderBy("created_time", "desc")
            .limit(30)
            .get();

        const contents = postsSnapshot.docs.map((doc) => doc.data().content);

        const prompt = `あなたは30代の男性です。その上で以下の文章を基にこの文章の作成者がSNSに投稿する際に書きそうな文章を、` +
        `10～100字程度で作成して下さい:\n${contents.join("\n")}`;

        const apiKey = await openAiApiKey.value();

        const aiResponse = await axios.post(
            "https://api.openai.com/v1/completions",
            {
              model: "text-davinci-003",
              prompt,
              max_tokens: 150,
            },
            {
              headers: {
                "Authorization": `Bearer ${apiKey}`,
                "Content-Type": "application/json",
              },
            },
        );

        const generatedContent = aiResponse.data.choices[0].text.trim();

        const postId = db.collection("posts").doc().id; // ランダムIDを生成！

        const newPost = {
          content: generatedContent,
          post_account_id: "c1nvtSQSiSOwCrEKEADK",
          post_user_id: "g",
          created_time: new Date(),
          media_url: null,
          is_video: false,
          post_id: postId,
          reply: null,
          reply_limit: false,
          repost: null,
          category: null,
          clip: false,
          clipTime: null,
          hide: false,
        };

        await db.collection("posts").doc(postId).set(newPost);

        console.log("New post added successfully:", newPost);
      } catch (error) {
        console.log("Error generating and adding post:", error);
      }
    },
);

exports.updateRanking = onSchedule("0 0,12 * * *", async (event) => {
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
