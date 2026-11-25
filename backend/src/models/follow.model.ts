import { pool } from "#database/pg";

// Who follows whom (user_follows in database/migrations/005). The Following
// and Followers numbers on a profile are counted from here, never stored.

export interface FollowSummary {
    followers_count: number;
    following_count: number;
    // Whether the viewer follows this user; false for a signed-out viewer
    // and on the viewer's own profile.
    is_following: boolean;
}

export const FollowModel = {
    // Following someone twice is the same as following them once.
    async follow(followerId: number, followeeId: number): Promise<void> {
        await pool.query(`INSERT INTO user_follows (follower_id, followee_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
            [followerId, followeeId]);
    },

    async unfollow(followerId: number, followeeId: number): Promise<void> {
        await pool.query(`DELETE FROM user_follows WHERE follower_id = $1 AND followee_id = $2`, [followerId, followeeId]);
    },

    // The counts for `userId`'s profile, as `viewerId` sees it.
    async summary(userId: number, viewerId?: number): Promise<FollowSummary> {
        const { rows: [row] } = await pool.query(`
            SELECT (SELECT COUNT(*) FROM user_follows WHERE followee_id = $1) AS followers_count,
                   (SELECT COUNT(*) FROM user_follows WHERE follower_id = $1) AS following_count,
                   EXISTS (SELECT 1 FROM user_follows WHERE follower_id = $2 AND followee_id = $1) AS is_following
        `, [userId, viewerId ?? null]);
        return {
            followers_count: Number(row.followers_count),
            following_count: Number(row.following_count),
            is_following: row.is_following === true,
        };
    },
};
