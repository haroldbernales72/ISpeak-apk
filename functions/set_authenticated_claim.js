
const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "ispeak-um",
});

async function main() {
  const auth = admin.auth();
  let nextPageToken;
  let updated = 0;

  do {
    const result = await auth.listUsers(1000, nextPageToken);

    for (const user of result.users) {
      const claims = user.customClaims || {};

      if (claims.role === "authenticated") {
        console.log(`Already configured: ${user.uid}`);
        continue;
      }

      await auth.setCustomUserClaims(user.uid, {
        ...claims,
        role: "authenticated",
      });

      updated++;
      console.log(`Updated: ${user.uid}`);
    }

    nextPageToken = result.pageToken;
  } while (nextPageToken);

  console.log(`Finished. Updated ${updated} users.`);
}

main().catch((error) => {
  console.error("Failed to update users:", error);
  process.exitCode = 1;
});
