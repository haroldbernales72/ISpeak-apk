const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "ispeak-um",
});

async function main() {
  const result = await admin.auth().listUsers(1000);

  console.log(`Found ${result.users.length} users.`);

  for (const user of result.users) {
    console.log({
      uid: user.uid,
      claims: user.customClaims || {},
    });
  }

  console.log("Finished. No user claims were changed.");
}

main().catch((error) => {
  console.error("Check failed:", error.message);
  process.exitCode = 1;
});