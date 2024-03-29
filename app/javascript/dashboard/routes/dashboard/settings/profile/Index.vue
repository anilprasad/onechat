<template>
  <div class="columns profile--settings">
    <form @submit.prevent="updateUser('profile')">
      <div class="small-12 row profile--settings--row">
        <div class="columns small-3">
          <h4 class="block-title">
            {{ $t('PROFILE_SETTINGS.FORM.PROFILE_SECTION.TITLE') }}
          </h4>
          <p>{{ $t('PROFILE_SETTINGS.FORM.PROFILE_SECTION.NOTE') }}</p>
        </div>
        <div class="columns small-9 medium-5">
          <woot-avatar-uploader
            :label="$t('PROFILE_SETTINGS.FORM.PROFILE_IMAGE.LABEL')"
            :src="avatarUrl"
            @change="handleImageUpload"
          />
          <div v-if="showDeleteButton" class="avatar-delete-btn">
            <woot-button
              type="button"
              color-scheme="alert"
              variant="hollow"
              size="small"
              @click="deleteAvatar"
            >
              {{ $t('PROFILE_SETTINGS.DELETE_AVATAR') }}
            </woot-button>
          </div>
          <label :class="{ error: $v.first_name.$error }">
            {{ $t('PROFILE_SETTINGS.FORM.FIRST_NAME.LABEL') }}
            <input
              v-model="first_name"
              type="text"
              :placeholder="$t('PROFILE_SETTINGS.FORM.FIRST_NAME.PLACEHOLDER')"
              @input="$v.first_name.$touch"
            />
            <span v-if="$v.first_name.$error" class="message">
              {{ $t('PROFILE_SETTINGS.FORM.FIRST_NAME.ERROR') }}
            </span>
          </label>
          <label :class="{ error: $v.last_name.$error }">
            {{ $t('PROFILE_SETTINGS.FORM.LAST_NAME.LABEL') }}
            <input
              v-model="last_name"
              type="text"
              :placeholder="$t('PROFILE_SETTINGS.FORM.LAST_NAME.PLACEHOLDER')"
              @input="$v.last_name.$touch"
            />
            <span v-if="$v.last_name.$error" class="message">
              {{ $t('PROFILE_SETTINGS.FORM.LAST_NAME.ERROR') }}
            </span>
          </label>
          <label :class="{ error: $v.phone.$error }">
            {{ $t('PROFILE_SETTINGS.FORM.PHONE.LABEL') }}
            <input
              v-model="phone"
              type="text"
              :placeholder="$t('PROFILE_SETTINGS.FORM.PHONE.PLACEHOLDER')"
              @input="$v.phone.$touch"
            />
            <span v-if="$v.phone.$error" class="message">
              {{ $t('PROFILE_SETTINGS.FORM.PHONE.ERROR') }}
            </span>
          </label>
          <label :class="{ error: $v.displayName.$error }">
            {{ $t('PROFILE_SETTINGS.FORM.DISPLAY_NAME.LABEL') }}
            <input
              v-model="displayName"
              type="text"
              :placeholder="
                $t('PROFILE_SETTINGS.FORM.DISPLAY_NAME.PLACEHOLDER')
              "
              @input="$v.displayName.$touch"
            />
          </label>
          <label :class="{ error: $v.email.$error }">
            {{ $t('PROFILE_SETTINGS.FORM.EMAIL.LABEL') }}
            <input
              v-model.trim="email"
              type="email"
              :placeholder="$t('PROFILE_SETTINGS.FORM.EMAIL.PLACEHOLDER')"
              @input="$v.email.$touch"
            />
            <span v-if="$v.email.$error" class="message">
              {{ $t('PROFILE_SETTINGS.FORM.EMAIL.ERROR') }}
            </span>
          </label>
          <woot-button type="submit" :is-loading="isProfileUpdating">
            {{ $t('PROFILE_SETTINGS.BTN_TEXT') }}
          </woot-button>
        </div>
      </div>
    </form>
    <message-signature />
    <change-password />
    <notification-settings />
    <div class="profile--settings--row row">
      <div class="columns small-3">
        <h4 class="block-title">
          {{ $t('PROFILE_SETTINGS.FORM.ACCESS_TOKEN.TITLE') }}
        </h4>
        <p>
          {{
            useInstallationName(
              $t('PROFILE_SETTINGS.FORM.ACCESS_TOKEN.NOTE'),
              globalConfig.installationName
            )
          }}
        </p>
      </div>
      <div class="columns small-9 medium-5">
        <woot-code :script="currentUser.access_token"></woot-code>
      </div>
    </div>
  </div>
</template>

<script>
import { required, minLength, email } from 'vuelidate/lib/validators';
import { mapGetters } from 'vuex';
import { clearCookiesOnLogout } from '../../../../store/utils/api';
import NotificationSettings from './NotificationSettings';
import alertMixin from 'shared/mixins/alertMixin';
import ChangePassword from './ChangePassword';
import MessageSignature from './MessageSignature';
import globalConfigMixin from 'shared/mixins/globalConfigMixin';

export default {
  components: {
    NotificationSettings,
    ChangePassword,
    MessageSignature,
  },
  mixins: [alertMixin, globalConfigMixin],
  data() {
    return {
      avatarFile: '',
      avatarUrl: '',
      first_name: '',
      last_name: '',
      phone: '',
      displayName: '',
      email: '',
      isProfileUpdating: false,
      errorMessage: '',
    };
  },
  validations: {
    first_name: {
      required,
      minLength: minLength(1),
    },
    last_name: {
      required,
      minLength: minLength(1),
    },
    phone: {
      required,
      minLength: minLength(1),
    },
    displayName: {},
    email: {
      required,
      email,
    },
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      currentUserId: 'getCurrentUserID',
      globalConfig: 'globalConfig/get',
    }),
  },
  watch: {
    currentUserId(newCurrentUserId, prevCurrentUserId) {
      if (prevCurrentUserId !== newCurrentUserId) {
        this.initializeUser();
      }
    },
  },
  mounted() {
    if (this.currentUserId) {
      this.initializeUser();
    }
  },
  methods: {
    initializeUser() {
      this.first_name = this.currentUser.first_name;
      this.last_name = this.currentUser.last_name;
      this.phone = this.currentUser.phone;
      this.email = this.currentUser.email;
      this.avatarUrl = this.currentUser.avatar_url;
      this.displayName = this.currentUser.display_name;
    },
    async updateUser() {
      this.$v.$touch();
      if (this.$v.$invalid) {
        this.showAlert(this.$t('PROFILE_SETTINGS.FORM.ERROR'));
        return;
      }

      this.isProfileUpdating = true;
      const hasEmailChanged = this.currentUser.email !== this.email;
      try {
        await this.$store.dispatch('updateProfile', {
          first_name: this.first_name,
          last_name: this.last_name,
          phone: this.phone,
          email: this.email,
          avatar: this.avatarFile,
          displayName: this.displayName,
        });
        this.isProfileUpdating = false;
        if (hasEmailChanged) {
          clearCookiesOnLogout();
          this.errorMessage = this.$t('PROFILE_SETTINGS.AFTER_EMAIL_CHANGED');
        }
        this.errorMessage = this.$t('PROFILE_SETTINGS.UPDATE_SUCCESS');
      } catch (error) {
        this.errorMessage = this.$t('RESET_PASSWORD.API.ERROR_MESSAGE');
        if (error?.response?.data?.error) {
          this.errorMessage = error.response.data.error;
        }
      } finally {
        this.isProfileUpdating = false;
        this.showAlert(this.errorMessage);
      }
    },
    handleImageUpload({ file, url }) {
      this.avatarFile = file;
      this.avatarUrl = url;
    },
    async deleteAvatar() {
      try {
        await this.$store.dispatch('deleteAvatar');
        this.avatarUrl = '';
        this.avatarFile = '';
        this.showAlert(this.$t('PROFILE_SETTINGS.AVATAR_DELETE_SUCCESS'));
      } catch (error) {
        this.showAlert(this.$t('PROFILE_SETTINGS.AVATAR_DELETE_FAILED'));
      }
    },
    showDeleteButton() {
      return this.avatarUrl && !this.avatarUrl.includes('www.gravatar.com');
    },
  },
};
</script>

<style lang="scss">
@import '~dashboard/assets/scss/variables.scss';
@import '~dashboard/assets/scss/mixins.scss';

.profile--settings {
  padding: 24px;
  overflow: auto;
}

.profile--settings--row {
  @include border-normal-bottom;
  padding: $space-normal;
  .small-3 {
    padding: $space-normal $space-medium $space-normal 0;
  }
  .small-9 {
    padding: $space-normal;
  }
}
</style>
