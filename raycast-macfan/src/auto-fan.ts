import { showToast, Toast } from "@raycast/api";
import { resetFanControl, toErrorMessage } from "./macfan";

export default async function Command() {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: "Returning fans to Auto"
  });

  try {
    await resetFanControl();
    toast.style = Toast.Style.Success;
    toast.title = "Fans returned to Auto";
  } catch (error) {
    toast.style = Toast.Style.Failure;
    toast.title = "Could not reset fans";
    toast.message = toErrorMessage(error);
  }
}
